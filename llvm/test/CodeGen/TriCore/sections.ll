; RUN: llc -march=tricore -filetype=obj %s -o %t.o
; RUN: llvm-readobj --elf-output-style=GNU -S %t.o | FileCheck %s

; Test that TriCore emits correct ELF section flags for standard sections

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; CHECK: Section Headers:
; CHECK: .text
; CHECK-SAME: PROGBITS
; CHECK-SAME: AX
; CHECK: .data
; CHECK-SAME: PROGBITS
; CHECK-SAME: WA
; CHECK: .rodata
; CHECK-SAME: PROGBITS
; CHECK-SAME: {{[ ]}}A{{[ ]}}

define i32 @func(i32 %x) {
  ; This function goes into .text (ax flags)
  %result = add i32 %x, 42
  ret i32 %result
}

@global_data = global i32 123, align 4
; This goes into .data (wa flags)

@global_const = constant i32 456, align 4
; This goes into .rodata (a flags)
