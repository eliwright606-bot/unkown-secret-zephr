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
//  they only need to exist for the compiler. Each one simply
//  delegates to the equivalent scalar routine in nnue_scalar.go.
//
//  Families covered:
//      addSingleAVX2_N -> addSingleScalar
//      subSingleAVX2_N -> subSingleScalar
//      moveAVX2_N      -> moveScalar
//      captureAVX2_N   -> captureScalar
//      castleAVX2_N    -> castleScalar
//      getEvalAVX2_N   -> evalScalar
//
// ================================================================

package main

func addSingleAVX2_64(a, w *int16)    { addSingleScalar(a, w) }
func addSingleAVX2_128(a, w *int16)   { addSingleScalar(a, w) }
func addSingleAVX2_256(a, w *int16)   { addSingleScalar(a, w) }
func addSingleAVX2_384(a, w *int16)   { addSingleScalar(a, w) }
func addSingleAVX2_512(a, w *int16)   { addSingleScalar(a, w) }
func addSingleAVX2_768(a, w *int16)   { addSingleScalar(a, w) }
func addSingleAVX2_1024(a, w *int16)  { addSingleScalar(a, w) }

func subSingleAVX2_64(a, w *int16)    { subSingleScalar(a, w) }
func subSingleAVX2_128(a, w *int16)   { subSingleScalar(a, w) }
func subSingleAVX2_256(a, w *int16)   { subSingleScalar(a, w) }
func subSingleAVX2_384(a, w *int16)   { subSingleScalar(a, w) }
func subSingleAVX2_512(a, w *int16)   { subSingleScalar(a, w) }
func subSingleAVX2_768(a, w *int16)   { subSingleScalar(a, w) }
func subSingleAVX2_1024(a, w *int16)  { subSingleScalar(a, w) }

func moveAVX2_64(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_128(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_256(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_384(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_512(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_768(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}
func moveAVX2_1024(a0, a1 *int16, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar(a0, a1, wFrom0, wTo0, wFrom1, wTo1)
}

func captureAVX2_64(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_128(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_256(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_384(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_512(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_768(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func captureAVX2_1024(a0, a1 *int16, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar(a0, a1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}

func castleAVX2_64(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_128(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_256(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_384(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_512(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_768(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}
func castleAVX2_1024(a0, a1 *int16, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar(a0, a1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}

func getEvalAVX2_64(a0, a1, w0, w1 *int16, sum *int32)    { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_128(a0, a1, w0, w1 *int16, sum *int32)   { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_256(a0, a1, w0, w1 *int16, sum *int32)   { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_384(a0, a1, w0, w1 *int16, sum *int32)   { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_512(a0, a1, w0, w1 *int16, sum *int32)   { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_768(a0, a1, w0, w1 *int16, sum *int32)   { evalScalar(a0, a1, w0, w1, sum) }
func getEvalAVX2_1024(a0, a1, w0, w1 *int16, sum *int32)  { evalScalar(a0, a1, w0, w1, sum) }

// 3-operand fused kernels (used only for 512-wide nets on amd64);
// scalar equivalents live in nnue_scalar.go
func moveAVX2_512_3op(dst0, src0, dst1, src1, wFrom0, wTo0, wFrom1, wTo1 *int16) {
	moveScalar3(dst0, src0, dst1, src1, wFrom0, wTo0, wFrom1, wTo1)
}
func captureAVX2_512_3op(dst0, src0, dst1, src1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1 *int16) {
	captureScalar3(dst0, src0, dst1, src1, wTo0, wFrom0, wCap0, wTo1, wFrom1, wCap1)
}
func castleAVX2_512_3op(dst0, src0, dst1, src1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1 *int16) {
	castleScalar3(dst0, src0, dst1, src1, wKFrom0, wKTo0, wRFrom0, wRTo0, wKFrom1, wKTo1, wRFrom1, wRTo1)
}

// Multilayer eval kernel: unreachable on non-amd64 (hasAVX2 is false
// there and both call sites are guarded by it); stub for the compiler.
func getEvalMultilayerAVX2(
	a0, a1 *int16,
	l1w *int8,
	l1b *float32,
	l2w *float32,
	l2b *float32,
	l3w *float32,
	l3b float32,
	scale float32,
	out *int32,
) {
	*out = 0
}
