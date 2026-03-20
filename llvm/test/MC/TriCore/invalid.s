# RUN: not llvm-mc -triple tricore-unknown-elf %s -o /dev/null 2>&1 | FileCheck %s

        calli D4

# CHECK: error: