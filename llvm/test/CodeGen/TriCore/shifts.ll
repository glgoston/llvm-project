; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i32 @shl_imm(i32 %x) {
; CHECK-LABEL: shl_imm:
; CHECK: sh
; CHECK: ret
  %r = shl i32 %x, 3
  ret i32 %r
}

define i32 @ashr_imm(i32 %x) {
; CHECK-LABEL: ashr_imm:
; CHECK: sha
; CHECK: ret
  %r = ashr i32 %x, 1
  ret i32 %r
}

define i32 @shl_zero(i32 %x) {
; CHECK-LABEL: shl_zero:
; CHECK: mov %d2, %d4
; CHECK: ret
  %r = shl i32 %x, 0
  ret i32 %r
}

define i32 @shl_thirtytwo(i32 %x) {
; CHECK-LABEL: shl_thirtytwo:
; CHECK: ret
  %r = shl i32 %x, 32
  ret i32 %r
}

define i32 @sra_var(i32 %x, i32 %amt) {
; CHECK-LABEL: sra_var:
; CHECK: sub %d2, %d2, %d5
; CHECK: sha %d2, %d4, %d2
; CHECK: ret
  %r = ashr i32 %x, %amt
  ret i32 %r
}