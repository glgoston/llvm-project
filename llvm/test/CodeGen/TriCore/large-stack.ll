; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i32 @large_stack(i32 %x) {
; CHECK-LABEL: large_stack:
; CHECK: sub.a %a10, 512
; CHECK: st.w [%a10] -512, %d2
; CHECK: add.a %a10, %a10, %a12
; CHECK: ret
entry:
  %buf = alloca [128 x i32], align 4
  %p = getelementptr inbounds [128 x i32], ptr %buf, i32 0, i32 37
  store i32 %x, ptr %p, align 4
  %v = load i32, ptr %p, align 4
  ret i32 %v
}