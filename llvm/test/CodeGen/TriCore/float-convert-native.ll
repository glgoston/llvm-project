; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s
; Verify native FPU type-conversion instructions emitted on tc162 (FeatureFP).

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; CHECK-LABEL: sitofp_i32:
; CHECK:       itof
; CHECK-NOT:   __floatsisf
; CHECK:       ret
define float @sitofp_i32(i32 %a) {
  %r = sitofp i32 %a to float
  ret float %r
}

; CHECK-LABEL: uitofp_i32:
; CHECK:       utof
; CHECK-NOT:   __floatunsisf
; CHECK:       ret
define float @uitofp_i32(i32 %a) {
  %r = uitofp i32 %a to float
  ret float %r
}

; CHECK-LABEL: fptosi_f32:
; CHECK:       ftoiz
; CHECK-NOT:   __fixsfsi
; CHECK:       ret
define i32 @fptosi_f32(float %x) {
  %r = fptosi float %x to i32
  ret i32 %r
}

; CHECK-LABEL: fptoui_f32:
; CHECK:       ftouz
; CHECK-NOT:   __fixunssfsi
; CHECK:       ret
define i32 @fptoui_f32(float %x) {
  %r = fptoui float %x to i32
  ret i32 %r
}
