// RUN: %clang -target tricore-unknown-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -target tricore-pc-none-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -### %s -target tricore-unknown-elf -Xclang -target-cpu -Xclang tc162 2>&1 \
// RUN:   | FileCheck -check-prefix=CPU %s

// CPU: "-target-cpu" "tc162"
