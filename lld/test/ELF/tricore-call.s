# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=RELOC %s
# RUN: llvm-objdump --triple=tricore -d %t | FileCheck %s

# Test R_TRICORE_24REL relocation for function calls

# RELOC: Relocations [
# RELOC:   Section ({{[0-9]+}}) .rela.text {
# RELOC-NEXT:    R_TRICORE_24REL
# RELOC:   }
# RELOC: ]

.text
.globl _start
_start:
  # CHECK-LABEL: <_start>:
  # CHECK:       call
  call func1
  # CHECK-NEXT:  ret
  ret

.globl func1
func1:
  # CHECK-LABEL: <func1>:
  # CHECK:       ret
  ret
