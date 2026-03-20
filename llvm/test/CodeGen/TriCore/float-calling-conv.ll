; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

declare float @callee(float, float)

define float @id_f32(float %x) {
; CHECK-LABEL: id_f32:
; CHECK: mov %d2, %d4
; CHECK: ret
  ret float %x
}

define float @call_f32(float %a, float %b) {
; CHECK-LABEL: call_f32:
; CHECK: call callee
; CHECK: ret
  %r = call float @callee(float %a, float %b)
  ret float %r
}