; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s
; Verify Phase D native FP ops on tc162 (FeatureFP): MADD.F and MSUB.F.

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

declare float @llvm.fma.f32(float, float, float)

; CHECK-LABEL: fma_native:
; CHECK:       madd.f
; CHECK:       ret
define float @fma_native(float %a, float %b, float %c) {
  %r = call float @llvm.fma.f32(float %a, float %b, float %c)
  ret float %r
}

; CHECK-LABEL: fmsub_native:
; CHECK:       msub.f
; CHECK:       ret
define float @fmsub_native(float %a, float %b, float %c) {
  %na = fneg float %a
  %r = call float @llvm.fma.f32(float %na, float %b, float %c)
  ret float %r
}


