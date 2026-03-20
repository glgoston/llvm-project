// RUN: %clang_cc1 -triple tricore-unknown-elf -E -dM %s | FileCheck --check-prefix=TRICORE %s
// RUN: %clang_cc1 -triple tricore-unknown-elf -target-cpu tc162 -E -dM %s | FileCheck --check-prefix=TC162 %s

// TRICORE: #define __ELF__ 1
// TRICORE: #define __TRICORE__ 1
// TRICORE: #define __tricore__ 1

// TC162: #define __TC162__ 1
