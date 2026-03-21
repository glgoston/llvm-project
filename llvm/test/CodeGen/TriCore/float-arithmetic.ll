; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define float @add_f32(float %a, float %b) {
; CHECK-LABEL: add_f32:
; CHECK: add.f
; CHECK: ret
  %r = fadd float %a, %b
  ret float %r
}

define float @mul_f32(float %a, float %b) {
; CHECK-LABEL: mul_f32:
; CHECK: mul.f
; CHECK: ret
  %r = fmul float %a, %b
  ret float %r
}

define float @sub_f32(float %a, float %b) {
; CHECK-LABEL: sub_f32:
; CHECK: sub.f
; CHECK: ret
  %r = fsub float %a, %b
  ret float %r
}

define float @div_f32(float %a, float %b) {
; CHECK-LABEL: div_f32:
; CHECK: div.f
; CHECK: ret
  %r = fdiv float %a, %b
  ret float %r
}