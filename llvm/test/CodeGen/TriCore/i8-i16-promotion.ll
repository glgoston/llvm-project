; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i32 @add_i8(i8 %a, i8 %b) {
; CHECK-LABEL: add_i8:
; CHECK: extr %d3, %d4, 0, 8
; CHECK: extr %d2, %d5, 0, 8
; CHECK: add %d2, %d3
; CHECK: ret
  %ea = sext i8 %a to i32
  %eb = sext i8 %b to i32
  %s = add i32 %ea, %eb
  ret i32 %s
}

define i32 @add_i16(i16 %a, i16 %b) {
; CHECK-LABEL: add_i16:
; CHECK: extr %d3, %d4, 0, 16
; CHECK: extr %d2, %d5, 0, 16
; CHECK: add %d2, %d3
; CHECK: ret
  %ea = sext i16 %a to i32
  %eb = sext i16 %b to i32
  %s = add i32 %ea, %eb
  ret i32 %s
}