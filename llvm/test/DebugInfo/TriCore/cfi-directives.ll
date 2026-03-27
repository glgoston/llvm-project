; RUN: llc -mtriple=tricore -filetype=asm %s -o - | FileCheck %s

; Check that CFI (Call Frame Information) directives are emitted.

; CHECK-LABEL: test_cfi:
; CHECK: .cfi_startproc
; CHECK: sub.a
; CHECK: .cfi_def_cfa_offset 40
; CHECK: ret
; CHECK: .cfi_endproc

define i32 @test_cfi(i32 %x, i32 %y) {
entry:
  %array = alloca [10 x i32], align 4
  %ptr = getelementptr inbounds [10 x i32], ptr %array, i32 0, i32 %x
  store i32 %y, ptr %ptr, align 4
  %val = load i32, ptr %ptr, align 4
  ret i32 %val
}
