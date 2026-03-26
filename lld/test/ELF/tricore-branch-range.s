# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: not ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# Test that out-of-range call generates error
# R_TRICORE_24REL has 24-bit signed range (±8MB instruction range, ±16MB byte range)

.text
.globl _start
_start:
  call far_target
  ret

# CHECK: error: {{.*}}.o:(.text+0x0): relocation R_TRICORE_24REL out of range

# Place target very far away to trigger error (beyond 24-bit range)
.space 0x2000000

far_target:
  ret
