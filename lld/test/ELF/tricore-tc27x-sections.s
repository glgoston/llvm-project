# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld -T %S/tricore-tc27x.lds %t.o -o %t.elf
# RUN: llvm-readobj --section-headers %t.elf | FileCheck %s

# Test TC27x-specific section placement: fast code in PSPR, shared data in LMU, etc.

# CHECK: Name: .text_pspr
# CHECK: Address: 0xC0000000

# CHECK: Name: .shared
# CHECK: Address: 0xB0000000

# CHECK: Name: .nvdata  
# CHECK: Address: 0xAF000000

.text
.globl _start
_start:
  ret

# Fast critical function should go to PSPR (0xC0000000)
# Note: Cannot be called directly from PFLASH due to distance
.section .text.pspr, "ax"
.globl fast_function
fast_function:
  ret

# Shared data should go to LMU SRAM (0xB0000000)
.section .shared, "aw"
.globl shared_var
shared_var:
  .long 0x12345678

# Non-volatile data should go to DFLASH (0xAF000000)
.section .nvdata, "a"
.globl config_data
config_data:
  .long 0xDEADBEEF
