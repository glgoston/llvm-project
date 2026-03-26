# RUN: llvm-mc -triple=tricore -filetype=obj %s -o %t.o
# RUN: llvm-objdump --triple=tricore -d -r %t.o | FileCheck %s

# Test that llvm-objdump can disassemble TriCore code and show relocations

.text
.globl test_func
test_func:
# CHECK-LABEL: <test_func>:
  call external_func
# CHECK:         call 0
# CHECK-NEXT:    R_TRICORE_24REL{{.*}}external_func
  
  jnz D0, branch_target
# CHECK:  jnz %d0, 0

branch_target:
  ret
# CHECK:  ret

.data
.globl data_var
data_var:
  .long external_symbol
