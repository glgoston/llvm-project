; RUN: llc -march=tricore -mcpu=tc16 -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define float @add_f32(float %a, float %b) {
; CHECK-LABEL: add_f32:
; CHECK: call __addsf3
; CHECK: ret
  %r = fadd float %a, %b
  ret float %r
}

define i32 @fptosi_f32(float %x) {
; CHECK-LABEL: fptosi_f32:
; CHECK: call __fixsfsi
; CHECK: ret
  %r = fptosi float %x to i32
  ret i32 %r
}

define i32 @fcmp_olt_f32(float %a, float %b) {
; CHECK-LABEL: fcmp_olt_f32:
; CHECK: call __ltsf2
; CHECK: ret
  %c = fcmp olt float %a, %b
  %r = zext i1 %c to i32
  ret i32 %r
}
