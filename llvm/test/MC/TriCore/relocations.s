# RUN: llvm-mc -triple tricore-unknown-elf -filetype=obj %s -o %t
# RUN: llvm-readobj -r %t | FileCheck %s

        call callee
        jnz D4, branch_target
        ret

# CHECK: Relocations [
# CHECK: Section ({{[0-9]+}}) .rel.text {
# CHECK: 0x0 R_TRICORE_24REL callee
# CHECK: 0x4 R_TRICORE_16REL branch_target