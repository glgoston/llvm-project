; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

declare void @llvm.va_start(ptr)
declare void @llvm.va_end(ptr)

define i32 @sum_first_vararg(i32 %count, ...) {
; CHECK-LABEL: sum_first_vararg:
; CHECK: mov %d2, %d5
; CHECK: st.w [%a10] -8, %d2
; CHECK: st.w [%a10] -12, %d3
; CHECK: ret
entry:
  %ap = alloca ptr, align 4
  call void @llvm.va_start(ptr %ap)
  %apcur = load ptr, ptr %ap, align 4
  %val = load i32, ptr %apcur, align 4
  call void @llvm.va_end(ptr %ap)
  ret i32 %val
}