#import "engine.h"

#include <string>
#include <deque>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <thread>
#include <iostream>
#include <sstream>
#include <cstring>
#include <atomic>

// Midnight engine (https://github.com/archishou/MidnightChessEngine) — UCI
// loop is run in-process on a background thread with std::cin/std::cout
// redirected through custom streambufs, exactly like the Stockfish wrapper
// this file is derived from.

#include "uci_interpreter/uci_interpreter.h"
#include "engine/engine.h"

static std::atomic<bool> gEngineReady{false};

namespace {

class InBuf : public std::streambuf {
    std::mutex m;
    std::condition_variable cv;
    std::deque<std::string> q;
    std::string cur;
    size_t pos = 0;
protected:
    int underflow() override {
        std::unique_lock<std::mutex> lk(m);
        while (pos >= cur.size()) {
            while (q.empty()) cv.wait(lk);
            cur = q.front(); q.pop_front(); pos = 0;
        }
        return traits_type::to_int_type(cur[pos]);
    }
    int uflow() override {
        int c = underflow();
        if (c != traits_type::eof()) pos++;
        return c;
    }
public:
    void push(const std::string &s) {
        std::lock_guard<std::mutex> lk(m);
        q.push_back(s);
        cv.notify_one();
    }
};

class OutBuf : public std::streambuf {
    std::mutex m;
    std::string line;
    std::function<void(const std::string &)> onLine;
protected:
    int overflow(int c) override {
        if (c == traits_type::eof()) return c;
        std::string done;
        bool flush = false;
        {
            std::lock_guard<std::mutex> lk(m);
            if (c == '\n') { done.swap(line); flush = true; }
            else line.push_back((char)c);
        }
        if (flush) onLine(done);
        return c;
    }
    std::streamsize xsputn(const char *s, std::streamsize n) override {
        for (std::streamsize i = 0; i < n; i++) overflow((unsigned char)s[i]);
        return n;
    }
public:
    void setHandler(std::function<void(const std::string &)> h) { onLine = std::move(h); }
};

InBuf  gIn;
OutBuf gOut;

#define MAXPV 8
struct Cand { std::string move; bool hasScore = false; bool isMate = false; int score = 0; bool filled = false; };

struct Req { std::string fen; int depth; int elo; int multipv; EngineResultBlock cb; };

std::mutex        gReqMutex;
std::deque<Req>   gQueue;
bool              gBusy = false;
EngineResultBlock gPending = nil;
Cand              gCand[MAXPV + 1];
int               gWantPV = 1;

void resetCands() {
    for (int i = 0; i <= MAXPV; i++) gCand[i] = Cand();
}

// Midnight supports "go movetime X" only (no "go depth", and its "stop" is a
// no-op), so the depth slider is mapped onto a search time budget. Midnight
// is a fast NEON NNUE engine, so even deep settings finish quickly.
static int depthToMovetime(int depth) {
    if (depth < 1) depth = 1;
    if (depth > 15) depth = 15;
    return 120 + depth * 260;   // d1: 380ms ... d8: 2200ms ... d15: 4020ms
}

void startNext_locked() {
    if (gBusy || gQueue.empty()) return;
    Req r = gQueue.front(); gQueue.pop_front();
    gBusy = true;
    gPending = r.cb;
    gWantPV = r.multipv;
    resetCands();
    gIn.push(std::string("position fen ") + r.fen + "\n");
    gIn.push(std::string("go movetime ") + std::to_string(depthToMovetime(r.depth)) + "\n");
}

void handleLine(const std::string &ln) {

    if (ln.compare(0, 5, "info ") == 0) {
        size_t pvp = ln.find(" pv ");
        if (pvp == std::string::npos) return;
        // Midnight has no MultiPV: every info line is the main line
        int idx = 1;
        size_t mp = ln.find(" multipv ");
        if (mp != std::string::npos) { std::istringstream is(ln.substr(mp + 9)); is >> idx; }
        if (idx < 1 || idx > MAXPV) return;

        std::string firstMove;
        { std::istringstream is(ln.substr(pvp + 4)); is >> firstMove; }
        if (firstMove.empty()) return;

        Cand &c = gCand[idx];
        c.move = firstMove; c.filled = true;
        size_t sp = ln.find(" score ");
        if (sp != std::string::npos) {
            std::istringstream is(ln.substr(sp + 7));
            std::string kind; int val = 0;
            if (is >> kind >> val) {
                // Midnight prints mate scores as raw cp values near
                // +/-100000 (MATE_SCORE); convert them to "mate in N".
                if (kind == "cp") {
                    if (val > 90000 || val < -90000) {
                        c.hasScore = true; c.isMate = true;
                        c.score = (val > 0) ? (100000 - val + 1) / 2
                                            : -((100000 + val + 1) / 2);
                    } else {
                        c.hasScore = true; c.isMate = false; c.score = val;
                    }
                }
                else if (kind == "mate") { c.hasScore = true; c.isMate = true; c.score = val; }
            }
        }
        return;
    }

    if (ln.compare(0, 9, "bestmove ") == 0) {
        std::string bm;
        { std::istringstream is(ln.substr(9)); is >> bm; }

        EngineResultBlock cb = nil;
        EngineLine out[MAXPV];
        int count = 0;
        {
            std::lock_guard<std::mutex> lk(gReqMutex);
            cb = gPending; gPending = nil;
            gBusy = false;
            for (int i = 1; i <= gWantPV && i <= MAXPV; i++) {
                if (!gCand[i].filled) break;
                EngineLine &l = out[count];
                strncpy(l.move, gCand[i].move.c_str(), sizeof(l.move) - 1);
                l.move[sizeof(l.move) - 1] = '\0';
                l.hasScore = gCand[i].hasScore; l.isMate = gCand[i].isMate; l.score = gCand[i].score;
                count++;
            }

            if (count == 0) {
                EngineLine &l = out[0];
                strncpy(l.move, bm.c_str(), sizeof(l.move) - 1);
                l.move[sizeof(l.move) - 1] = '\0';
                l.hasScore = false; l.isMate = false; l.score = 0;
                count = 1;
            }
            startNext_locked();
        }
        if (cb) cb(out, count);
    }
}

void engineThread() {
    initialize_engine();

    gOut.setHandler(handleLine);
    std::cin.rdbuf(&gIn);
    std::cout.rdbuf(&gOut);

    gEngineReady.store(true);

    read_uci();   // never returns; loops on getline(std::cin)
}

} // namespace

extern "C" void EngineStart(void) {
    bool expected = false;
    static std::atomic<bool> gStarted{false};
    if (!gStarted.compare_exchange_strong(expected, true)) return;
    std::thread(engineThread).detach();
}

extern "C" void EngineStageFiles(const char *a, const char *b) {
    // Midnight embeds its NNUE net at compile time — nothing to stage
    (void)a; (void)b;
}

extern "C" void EngineGo(const char *fen, int depth, int elo, int multipv, EngineResultBlock done) {
    EngineStart();
    if (multipv < 1) multipv = 1; if (multipv > MAXPV) multipv = MAXPV;
    if (depth < 1) depth = 1;

    std::lock_guard<std::mutex> lk(gReqMutex);

    while (gQueue.size() >= 4) gQueue.pop_front();
    gQueue.push_back(Req{ std::string(fen), depth, elo, multipv, [done copy] });
    startNext_locked();
}

// Midnight is a black-box UCI engine here, so legality is checked with our
// own small validator: parse the FEN and reject positions where the side not
// to move is already in check (the classic illegal-position test).
namespace {

struct MiniPos {
    signed char pc[64];   // 0 empty; +1..6 = PNBRQK white; -1..-6 black
    int side;             // 0 white, 1 black

    bool load(const char *fen) {
        memset(pc, 0, sizeof(pc));
        side = 0;
        const char *p = fen;
        int sq = 56;
        int stage = 0;
        while (*p) {
            char c = *p++;
            if (c == ' ') { stage++; if (stage > 1) break; continue; }
            if (stage == 0) {
                if (c == '/') { sq -= 16; continue; }
                if (c >= '1' && c <= '8') { sq += (c - '0'); continue; }
                int t = 0, sgn = 1;
                switch (c) {
                    case 'P': t = 1; break; case 'p': t = 1; sgn = -1; break;
                    case 'N': t = 2; break; case 'n': t = 2; sgn = -1; break;
                    case 'B': t = 3; break; case 'b': t = 3; sgn = -1; break;
                    case 'R': t = 4; break; case 'r': t = 4; sgn = -1; break;
                    case 'Q': t = 5; break; case 'q': t = 5; sgn = -1; break;
                    case 'K': t = 6; break; case 'k': t = 6; sgn = -1; break;
                    default: return false;
                }
                if (sq < 0 || sq > 63) return false;
                pc[sq++] = (signed char)(t * sgn);
            } else if (stage == 1) {
                if (c == 'w') side = 0;
                else if (c == 'b') side = 1;
                else return false;
            }
        }
        int wk = 0, bk = 0;
        for (int i = 0; i < 64; i++) {
            if (pc[i] == 6) wk++;
            if (pc[i] == -6) bk++;
        }
        return wk == 1 && bk == 1;
    }

    int kingSq(int color) const {
        for (int i = 0; i < 64; i++)
            if (pc[i] == (color == 0 ? 6 : -6)) return i;
        return -1;
    }

    bool attacked(int sq, int byColor) const {
        static const int kn[8][2] = {{1,2},{2,1},{2,-1},{1,-2},{-1,-2},{-2,-1},{-2,1},{-1,2}};
        static const int kg[8][2] = {{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1},{1,-1}};
        static const int bd[4][2] = {{1,1},{1,-1},{-1,1},{-1,-1}};
        static const int rd[4][2] = {{1,0},{-1,0},{0,1},{0,-1}};
        int r = sq / 8, f = sq % 8;
        int sgn = (byColor == 0) ? 1 : -1;
        // pawns
        int pr = r + (byColor == 0 ? -1 : 1);
        if (pr >= 0 && pr < 8) {
            if (f > 0 && pc[pr * 8 + f - 1] == sgn * 1) return true;
            if (f < 7 && pc[pr * 8 + f + 1] == sgn * 1) return true;
        }
        // knights
        for (auto &d : kn) {
            int rr = r + d[0], ff = f + d[1];
            if (rr >= 0 && rr < 8 && ff >= 0 && ff < 8 && pc[rr * 8 + ff] == sgn * 2) return true;
        }
        // king
        for (auto &d : kg) {
            int rr = r + d[0], ff = f + d[1];
            if (rr >= 0 && rr < 8 && ff >= 0 && ff < 8 && pc[rr * 8 + ff] == sgn * 6) return true;
        }
        // sliders
        for (auto &d : bd) {
            int rr = r + d[0], ff = f + d[1];
            while (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
                int v = pc[rr * 8 + ff];
                if (v != 0) {
                    if (v == sgn * 3 || v == sgn * 5) return true;
                    break;
                }
                rr += d[0]; ff += d[1];
            }
        }
        for (auto &d : rd) {
            int rr = r + d[0], ff = f + d[1];
            while (rr >= 0 && rr < 8 && ff >= 0 && ff < 8) {
                int v = pc[rr * 8 + ff];
                if (v != 0) {
                    if (v == sgn * 4 || v == sgn * 5) return true;
                    break;
                }
                rr += d[0]; ff += d[1];
            }
        }
        return false;
    }
};

} // namespace

extern "C" bool EngineFenLegal(const char *fen) {
    if (!fen) return false;
    MiniPos p;
    if (!p.load(fen)) return false;
    // the side NOT to move must not be in check
    int other = 1 - p.side;
    int ks = p.kingSq(other);
    if (ks < 0) return false;
    return !p.attacked(ks, p.side);
}

extern "C" int EngineLegalMoves(const char *fen, char *out, int maxMoves) {
    // not used by the Midnight build — callers treat 0 as "unknown"
    (void)fen; (void)out; (void)maxMoves;
    return 0;
}
