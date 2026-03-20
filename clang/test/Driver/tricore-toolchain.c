// RUN: %clang -target tricore-unknown-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -target tricore-pc-none-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -target tricore-unknown-elf -target-cpu tc162 -v 2> %t
// RUN: grep 'Target: tricore-unknown-elf' %t
// RUN: grep -- '-march=tc162' %t || true
