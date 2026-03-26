# RUN: llvm-mc -triple tricore-unknown-elf -filetype=obj %s -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

        call callee
        jnz D4, branch_target
        ret

        .section .data
        .long data_symbol

# CHECK: Relocations [
# CHECK: Section ({{[0-9]+}}) .rel.text {
# CHECK: 0x0 R_TRICORE_24REL callee
# CHECK: 0x4 R_TRICORE_16REL branch_target
# CHECK-NOT: R_TRICORE_16REL branch_target
# CHECK: }
# CHECK: Section ({{[0-9]+}}) .rel.data {
# CHECK: 0x0 R_TRICORE_32ABS data_symbol
# CHECK: }
# CHECK: ]
