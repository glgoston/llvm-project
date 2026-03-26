# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld -pie %t.o -o %t.pie
# RUN: llvm-readobj --file-headers %t.pie | FileCheck --check-prefix=PIE %s
# RUN: llvm-objdump --triple=tricore -d %t.pie | FileCheck %s

# Test position-independent executable (PIE) linking
# TriCore bare-metal PIE works without GOT/PLT (static PIE)

# PIE: Type: SharedObject (0x3)

.text
.globl _start
_start:
  # CHECK-LABEL: <_start>:
  # CHECK:       call
  call helper
  ret

.globl helper
helper:
  # CHECK-LABEL: <helper>:
  ret

.data
.globl data_var
data_var:
  .long 0x12345678
