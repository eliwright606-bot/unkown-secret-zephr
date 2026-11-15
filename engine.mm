#import "engine.h"

#include <string>
#include <deque>
#include <mutex>
#include <thread>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <atomic>

// Go bridge (rodent_bridge.go, compiled to librodent.a via c-archive)
extern "C" {
void RodentInit(void);
void RodentSend(const char *cmd);
int  RodentFenLegal(const char *fen);
int  RodentLegalMoves(const char *fen, char *out, int maxLen);
}

#define MAXPV 8

struct Cand { std::string move; bool hasScore = false; bool isMate = false; int score = 0; bool filled = false; };
struct Req  { std::string fen; int depth; int multipv; EngineResultBlock cb; };

static std::mutex        gReqMutex;
static std::deque<Req>   gQueue;
static bool              gBusy = false;
static EngineResultBlock gPending = nil;
static Cand              gCand[MAXPV + 1];
static int               gWantPV = 1;

static std::atomic<bool> gReady{false};
static std::atomic<bool> gHandshakeSent{false};
static std::atomic<bool> gStarted{false};
static std::atomic<bool> gFilesStaged{false};

// paths staged by Tweak.xm before the first search
char gRodentNetPath[512]  = {0};
char gRodentBookPath[512] = {0};

void EngineStageFiles(const char *netPath, const char *bookPath) {
    if (netPath) { strncpy(gRodentNetPath, netPath, sizeof(gRodentNetPath) - 1); gRodentNetPath[sizeof(gRodentNetPath)-1] = 0; }
    if (bookPath) { strncpy(gRodentBookPath, bookPath, sizeof(gRodentBookPath) - 1); gRodentBookPath[sizeof(gRodentBookPath)-1] = 0; }
    gFilesStaged.store(true);
}

// --- Nimzoid personality for Rodent V (Pawel Koziol's tuning) ---
// likes closed positions, restricts opponent mobility, attacks the enemy king
static void sendPersonality(void) {
    bool expected = false;
    if (!gHandshakeSent.compare_exchange_strong(expected, true)) return;

    RodentSend("setoption name Hash value 64\n");
    if (gRodentNetPath[0])
        RodentSend((std::string("setoption name nnuePath value ") + gRodentNetPath + "\n").c_str());
    if (gRodentBookPath[0])
        RodentSend((std::string("setoption name mainBookPath value ") + gRodentBookPath + "\n").c_str());

    RodentSend("setoption name hceWeight value 60\n");
    RodentSend("setoption name nnueWeight value 30\n");
    RodentSend("setoption name horizontalMirroring value 1\n");
    RodentSend("setoption name nnueScale value 206\n");
    RodentSend("setoption name likesClosed value 100\n");
    RodentSend("setoption name kingTropism value 0\n");
    RodentSend("setoption name forwardness value 0\n");
    RodentSend("setoption name OwnMaterial value 100\n");
    RodentSend("setoption name OppMaterial value 100\n");
    RodentSend("setoption name OwnPST value 100\n");
    RodentSend("setoption name OppPST value 100\n");
    RodentSend("setoption name OwnMobility value 100\n");
    RodentSend("setoption name OppMobility value 125\n");
    RodentSend("setoption name OwnSafety value 90\n");
    RodentSend("setoption name OppSafety value 115\n");
    RodentSend("setoption name OwnPawns value 100\n");
    RodentSend("setoption name OppPawns value 100\n");
    RodentSend("setoption name OwnPassers value 100\n");
    RodentSend("setoption name OppPassers value 100\n");
    RodentSend("setoption name OwnThreats value 75\n");
    RodentSend("setoption name OppThreats value 75\n");
    RodentSend("setoption name OwnOther value 100\n");
    RodentSend("setoption name OppOther value 100\n");
    RodentSend("isready\n");
}

static void resetCands(void) {
    for (int i = 0; i <= MAXPV; i++) gCand[i] = Cand();
}

static void startNext_locked(void) {
    if (gBusy || gQueue.empty() || !gReady.load()) return;
    Req r = gQueue.front(); gQueue.pop_front();
    gBusy = true;
    gPending = r.cb;
    gWantPV = r.multipv;
    resetCands();
    RodentSend("stop\n"); // abort any stray search first
    RodentSend((std::string("setoption name MultiPV value ") + std::to_string(r.multipv) + "\n").c_str());
    RodentSend((std::string("position fen ") + r.fen + "\n").c_str());
    RodentSend((std::string("go depth ") + std::to_string(r.depth) + "\n").c_str());
}

// called on the Go output thread for every engine output line
extern "C" void rodentOnLine(const char *lineC) {
    std::string ln(lineC ? lineC : "");
    if (ln.empty()) return;

    if (ln.compare(0, 6, "uciok ") == 0 || ln.compare(0, 5, "uciok") == 0) {
        sendPersonality();
        return;
    }
    if (ln.compare(0, 8, "readyok ") == 0 || ln.compare(0, 7, "readyok") == 0) {
        gReady.store(true);
        std::lock_guard<std::mutex> lk(gReqMutex);
        startNext_locked();
        return;
    }

    if (ln.compare(0, 5, "info ") == 0) {
        size_t pvp = ln.find(" pv ");
        if (pvp == std::string::npos) return;
        int idx = 1;
        size_t mp = ln.find(" multipv ");
        if (mp != std::string::npos) { sscanf(ln.c_str() + mp + 9, "%d", &idx); }
        if (idx < 1 || idx > MAXPV) return;

        size_t mvStart = pvp + 4;
        size_t mvEnd = ln.find(' ', mvStart);
        std::string firstMove = (mvEnd == std::string::npos)
            ? ln.substr(mvStart) : ln.substr(mvStart, mvEnd - mvStart);
        if (firstMove.empty()) return;

        Cand &c = gCand[idx];
        c.move = firstMove; c.filled = true;
        size_t sp = ln.find(" score ");
        if (sp != std::string::npos) {
            char kind[8] = {0}; int val = 0;
            if (sscanf(ln.c_str() + sp + 7, "%7s %d", kind, &val) == 2) {
                if (strcmp(kind, "cp") == 0)        { c.hasScore = true; c.isMate = false; c.score = val; }
                else if (strcmp(kind, "mate") == 0) { c.hasScore = true; c.isMate = true; c.score = val; }
            }
        }
        return;
    }

    if (ln.compare(0, 9, "bestmove ") == 0) {
        size_t sp = ln.find(' ', 9);
        std::string bm = (sp == std::string::npos) ? ln.substr(9) : ln.substr(9, sp - 9);

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

extern "C" void EngineStart(void) {
    bool expected = false;
    if (!gStarted.compare_exchange_strong(expected, true)) return;
    // wait for the embedded net/book to be materialized so the Nimzoid
    // personality loads with the right nnuePath/mainBookPath
    for (int i = 0; i < 500 && !gFilesStaged.load(); i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    RodentInit();
    RodentSend("uci\n");
}

extern "C" void EngineGo(const char *fen, int depth, int multipv, EngineResultBlock done) {
    EngineStart();
    if (multipv < 1) multipv = 1; if (multipv > MAXPV) multipv = MAXPV;
    if (depth < 1) depth = 1;

    std::lock_guard<std::mutex> lk(gReqMutex);

    while (gQueue.size() >= 4) gQueue.pop_front();
    gQueue.push_back(Req{ std::string(fen), depth, multipv, [done copy] });
    startNext_locked();
}

extern "C" bool EngineFenLegal(const char *fen) {
    EngineStart();
    for (int i = 0; i < 400 && !gReady.load(); i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    if (!gReady.load()) return false;
    return RodentFenLegal(fen) != 0;
}

extern "C" int EngineLegalMoves(const char *fen, char *out, int maxMoves) {
    EngineStart();
    for (int i = 0; i < 400 && !gReady.load(); i++)
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    if (!gReady.load() || !out || maxMoves < 1) return 0;

    char buf[4096];
    buf[0] = 0;
    RodentLegalMoves(fen, buf, (int)sizeof(buf));

    // pack space separated uci moves into fixed 6-byte records
    int count = 0;
    char *tok = buf;
    while (tok && *tok && count < maxMoves) {
        char *next = strchr(tok, ' ');
        if (next) *next = 0;
        if (strlen(tok) >= 4) {
            strncpy(out + count * 6, tok, 5);
            out[count * 6 + 5] = '\0';
            count++;
        }
        tok = next ? next + 1 : NULL;
    }
    return count;
}
