# RUN: llvm-mc -triple=tricore -filetype=obj %s -o %t.o
# RUN: llvm-nm %t.o | FileCheck %s

# Test that llvm-nm can read TriCore symbol tables

.text
.globl exported_func
.type exported_func, @function
exported_func:
  ret

local_func:
  ret

.data
.globl exported_var
exported_var:
  .long 42

local_var:
  .long 0

# CHECK: T exported_func
# CHECK: D exported_var
# CHECK: t local_func
# CHECK: d local_var
