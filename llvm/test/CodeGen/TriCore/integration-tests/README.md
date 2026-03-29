# TriCore Integration Tests

This directory contains C source files and corresponding LLVM IR for integration testing of the TriCore backend.

## Test Files

### Complex Algorithmic Tests
- **31.qsort.c** - Quicksort implementation with string comparison
- **linkedlist.c** - Linked list operations and traversal
- **determinant.c** - Matrix determinant calculation
- **prime.c** - Prime number generation/checking

### Feature-Specific Tests
- **13.loop_test.c** - Basic loop constructs (for loops)
- **20.global_test.c** - Global variable handling (long long arrays)
- **21.switch_test.c** - Switch statement code generation
- **22.local_array_test.c** - Local array access patterns
- **23.func_call.c** - Function call conventions and parameter passing
- **24.twofile_1_test.c** - Multi-file compilation test (with 24_file2.c/h)
- **28.long_test.c** - 64-bit integer operations
- **29.long_cmp_test.c** - 64-bit integer comparisons

## Usage

These tests were originally from an LLVM 3.7.0 era TriCore backend project. They serve as:

1. **Integration test cases** - More complex than unit tests, demonstrate real-world code patterns
2. **Reference examples** - Show how C constructs map to TriCore assembly
3. **Regression tests** - Verify backend generates correct code for complex scenarios

## Generating LLVM IR

To regenerate the LLVM IR from C source:

```bash
clang -target tricore -S -emit-llvm -O0 source.c -o source.ll
```

## Converting to Proper LLVM Tests

The .ll files can be enhanced with RUN lines and FileCheck directives. Example:

```llvm
; RUN: llc -march=tricore -o - %s | FileCheck %s
; CHECK-LABEL: function_name:
; CHECK: expected instruction pattern
```

See the parent directory for examples of proper LLVM test format.
