# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump --triple=tricore -d %t | FileCheck %s

# Basic test: Link a simple TriCore program with call relocation

.text
.globl _start
_start:
  # CHECK-LABEL: <_start>:
  # CHECK:       call
  call external_func
  # CHECK-NEXT:  ret
  ret

.globl external_func
external_func:
  # CHECK-LABEL: <external_func>:
  # CHECK:       ret
  ret
