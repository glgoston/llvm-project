# REQUIRES: tricore
# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld %t.o -o %t.elf
# RUN: llvm-readobj --file-headers %t.elf | FileCheck %s

# CHECK: Machine: EM_TRICORE

## Test that LLD correctly handles TriCore object files.
## This verifies basic LTO infrastructure doesn't break TriCore support.

.text
.globl _start
.type _start, @function
_start:
  ret

.globl helper
.type helper, @function  
helper:
  ret
