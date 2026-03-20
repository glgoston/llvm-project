; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i32 @select_eq(i32 %a, i32 %b, i32 %x, i32 %y) {
; CHECK-LABEL: select_eq:
; CHECK: mov %d2, %d6
; CHECK: eq %d3, %d4, %d5
; CHECK: jnz %d3
; CHECK: mov %d2, %d7
; CHECK: ret
  %cmp = icmp eq i32 %a, %b
  %sel = select i1 %cmp, i32 %x, i32 %y
  ret i32 %sel
}