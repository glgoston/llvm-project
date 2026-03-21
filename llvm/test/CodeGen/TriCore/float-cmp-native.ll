; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s
; Verify native CMP.F emission for tc162 (FeatureFP) subtargets.
; Each function performs a float comparison and returns 0/1.

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; CHECK-LABEL: fcmp_oeq_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_oeq_f32(float %a, float %b) {
  %r = fcmp oeq float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}

; CHECK-LABEL: fcmp_olt_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_olt_f32(float %a, float %b) {
  %r = fcmp olt float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}

; CHECK-LABEL: fcmp_ogt_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_ogt_f32(float %a, float %b) {
  %r = fcmp ogt float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}

; CHECK-LABEL: fcmp_one_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_one_f32(float %a, float %b) {
  %r = fcmp one float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}

; CHECK-LABEL: fcmp_ord_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_ord_f32(float %a, float %b) {
  %r = fcmp ord float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}

; CHECK-LABEL: fcmp_uno_f32:
; CHECK:       cmp.f
; CHECK:       and
; CHECK:       ne
; CHECK:       ret
define i32 @fcmp_uno_f32(float %a, float %b) {
  %r = fcmp uno float %a, %b
  %e = zext i1 %r to i32
  ret i32 %e
}
