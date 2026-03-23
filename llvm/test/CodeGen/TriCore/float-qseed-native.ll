; RUN: llc -march=tricore -mcpu=tc162 %s -o - | FileCheck %s

; Test QSEED.F - reciprocal square root seed (approximate)
declare float @llvm.tricore.qseed.f32(float)

define float @qseed_native(float %x) {
  %r = call float @llvm.tricore.qseed.f32(float %x)
  ret float %r
}
; CHECK-LABEL: qseed_native:
; CHECK: qseed.f

