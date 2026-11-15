//go:build !amd64

// ================================================================
//  AVX2 stubs for non-amd64 builds of Rodent V
// ================================================================
//
//  nnue.go references the AVX2 assembly helpers unconditionally, but
//  they are only implemented in nnue_avx2_amd64.go (build tag amd64).
//  Upstream never builds on other architectures, so the references
//  were never noticed. On non-amd64 (e.g. iOS arm64) hasAVX2 is
//  always false, so these fallbacks are never called at runtime —
//  they only need to exist for the compiler.
//
// ================================================================

package main

import "unsafe"

func avx2StubAdd(a, w *int16, n int) {
	aa := unsafe.Slice(a, n)
	ww := unsafe.Slice(w, n)
	for i := 0; i < n; i++ {
		aa[i] += ww[i]
	}
}

func avx2StubSub(a, w *int16, n int) {
	aa := unsafe.Slice(a, n)
	ww := unsafe.Slice(w, n)
	for i := 0; i < n; i++ {
		aa[i] -= ww[i]
	}
}

func addSingleAVX2_64(a, w *int16)    { avx2StubAdd(a, w, 64) }
func addSingleAVX2_128(a, w *int16)   { avx2StubAdd(a, w, 128) }
func addSingleAVX2_256(a, w *int16)   { avx2StubAdd(a, w, 256) }
func addSingleAVX2_384(a, w *int16)   { avx2StubAdd(a, w, 384) }
func addSingleAVX2_512(a, w *int16)   { avx2StubAdd(a, w, 512) }
func addSingleAVX2_768(a, w *int16)   { avx2StubAdd(a, w, 768) }
func addSingleAVX2_1024(a, w *int16)  { avx2StubAdd(a, w, 1024) }

func subSingleAVX2_64(a, w *int16)    { avx2StubSub(a, w, 64) }
func subSingleAVX2_128(a, w *int16)   { avx2StubSub(a, w, 128) }
func subSingleAVX2_256(a, w *int16)   { avx2StubSub(a, w, 256) }
func subSingleAVX2_384(a, w *int16)   { avx2StubSub(a, w, 384) }
func subSingleAVX2_512(a, w *int16)   { avx2StubSub(a, w, 512) }
func subSingleAVX2_768(a, w *int16)   { avx2StubSub(a, w, 768) }
func subSingleAVX2_1024(a, w *int16)  { avx2StubSub(a, w, 1024) }
