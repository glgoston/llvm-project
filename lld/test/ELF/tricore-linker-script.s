# RUN: llvm-mc -filetype=obj -triple=tricore %s -o %t.o
# RUN: ld.lld -T %S/tricore-tc27x.lds %t.o -o %t.elf
# RUN: llvm-readobj --section-headers %t.elf | FileCheck %s

# Test that sections are placed in correct TC27x memory regions

.section .startup, "ax"
.globl _start
_start:
  call main
  ret

.text
.globl main
main:
  # CHECK: Name: .text
  # CHECK-NEXT: Type: SHT_PROGBITS
  # CHECK-NEXT: Flags [
  # CHECK-NEXT:   SHF_ALLOC
  # CHECK-NEXT:   SHF_EXECINSTR
  # CHECK-NEXT: ]
  # CHECK-NEXT: Address: 0x80000
  ret

.rodata
.globl const_data
const_data:
  # CHECK: Name: .rodata
  # CHECK: Flags [
  # CHECK-NEXT:   SHF_ALLOC
  # CHECK-NEXT: ]
  # CHECK: Address: 0x80000
  .long 0x12345678

.data
.globl var_data
var_data:
  # CHECK: Name: .data
  # CHECK: Flags [
  # CHECK-NEXT:   SHF_ALLOC
  # CHECK-NEXT:   SHF_WRITE
  # CHECK-NEXT: ]
  # CHECK: Address: 0xD0000000
  .long 0xAABBCCDD

.bss
.globl uninit_data
uninit_data:
  # CHECK: Name: .bss
  # CHECK: Type: SHT_NOBITS
  # CHECK: Address: 0xD0000
  .space 64
