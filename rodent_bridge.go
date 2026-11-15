// ================================================================
//  Rodent V <-> Objective-C bridge
// ================================================================
//
//  This file is appended to a checkout of Rodent V
//  (https://github.com/nescitus/Rodent-V) during the build. It is
//  compiled together with the engine into a static C archive via
//
//      GOOS=ios GOARCH=arm64 CGO_ENABLED=1 \
//      go build -buildmode=c-archive -o librodent.a .
//
//  It exposes a small C surface the iOS tweak links against:
//
//      RodentInit()                       start the UCI loop on a goroutine
//      RodentSend(cmd)                    push a UCI command into the engine
//      RodentFenLegal(fen)                1 if the FEN describes a playable position
//      RodentLegalMoves(fen, out, max)    space separated UCI legal moves, returns count
//
//  The engine's stdio is redirected into OS pipes so `fmt.Println`
//  output (info/bestmove lines) is forwarded line-by-line to the
//  host through `rodentOnLine`.
//
// ================================================================

package main

/*
#include <stdlib.h>
extern void rodentOnLine(const char *line);
*/
import "C"

import (
	"bufio"
	"fmt"
	"os"
	"sync"
	"unsafe"
)

var (
	rodentStartOnce sync.Once
	rodentIn        *os.File
	rodentInMu      sync.Mutex
)

//export RodentInit
func RodentInit() {
	rodentStartOnce.Do(func() {
		inR, inW, err := os.Pipe()
		if err != nil {
			return
		}
		outR, outW, err := os.Pipe()
		if err != nil {
			return
		}

		os.Stdin = inR   // uciLoop() scans from here
		os.Stdout = outW // fmt.Println / os.Stdout.Write land here
		rodentIn = inW

		// Forward engine output to the ObjC side, one line at a time.
		go func() {
			defer func() { recover() }()
			sc := bufio.NewScanner(outR)
			sc.Buffer(make([]byte, 65536), 65536)
			for sc.Scan() {
				line := sc.Text()
				if line == "" {
					continue
				}
				c := C.CString(line)
				C.rodentOnLine(c)
				C.free(unsafe.Pointer(c))
			}
		}()

		// Blocks forever, scanning commands from the pipe.
		go func() {
			defer func() { recover() }()
			uciLoop()
		}()
	})
}

//export RodentSend
func RodentSend(cmd *C.char) {
	if cmd == nil {
		return
	}
	s := C.GoString(cmd)
	rodentInMu.Lock()
	if rodentIn != nil {
		fmt.Fprintf(rodentIn, "%s\n", s)
	}
	rodentInMu.Unlock()
}

//export RodentFenLegal
func RodentFenLegal(fen *C.char) C.int {
	defer func() { recover() }()
	if fen == nil {
		return 0
	}
	var p Pos
	parseFEN(&p, C.GoString(fen))
	if p.king(White) == 0 || p.king(Black) == 0 {
		return 0
	}
	// The side NOT to move must not be in check.
	if isAttacked(&p, p.kingSq[opp(p.side)], p.side) {
		return 0
	}
	return 1
}

//export RodentLegalMoves
func RodentLegalMoves(fen *C.char, out *C.char, maxLen C.int) C.int {
	defer func() { recover() }()
	if fen == nil || out == nil || maxLen <= 0 {
		return 0
	}
	var p Pos
	parseFEN(&p, C.GoString(fen))

	list := make([]int, 512)
	n := genCaptures(&p, list)
	n += genQuiet(&p, list[n:])
	list = list[:n]

	buf := make([]byte, 0, int(maxLen))
	count := 0
	for _, m := range list {
		if m == 0 || !isLegal(&p, m) {
			continue
		}
		var u Update
		var r Revert
		makeMove(&p, &u, &r, m)
		ok := !p.selfInCheck()
		unmakeMove(&p, &u, &r)
		if !ok {
			continue
		}
		s := moveToStr(m)
		if count > 0 {
			buf = append(buf, ' ')
		}
		buf = append(buf, s...)
		count++
		if len(buf)+1 >= int(maxLen) {
			break
		}
	}

	dst := unsafe.Slice((*byte)(unsafe.Pointer(out)), int(maxLen))
	copy(dst, buf)
	if len(buf) < int(maxLen) {
		dst[len(buf)] = 0
	} else {
		dst[int(maxLen)-1] = 0
	}
	return C.int(count)
}

//export RodentVersion
func RodentVersion() *C.char {
	return C.CString("Rodent V " + versionString + " (nimzoid)")
}
