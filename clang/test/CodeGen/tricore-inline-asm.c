// RUN: %clang_cc1 -triple tricore-unknown-elf -emit-llvm %s -o - | FileCheck %s

// Test inline assembly constraints for TriCore

// Data register constraint 'd'
int test_data_reg(int x) {
  int result;
  // CHECK-LABEL: @test_data_reg
  // CHECK: call i32 asm "add $0, $1, $1", "=d,d"
  __asm__("add %0, %1, %1" : "=d"(result) : "d"(x));
  return result;
}

// Address register constraint 'a'
void* test_addr_reg(void* ptr) {
  void* result;
  // CHECK-LABEL: @test_addr_reg
  // CHECK: call ptr asm "mov.a $0, $1", "=a,a"
  __asm__("mov.a %0, %1" : "=a"(result) : "a"(ptr));
  return result;
}

// Extended register constraint 'e'
long long test_ext_reg(long long x) {
  long long result;
  // CHECK-LABEL: @test_ext_reg
  // CHECK: call i64 asm "mov.u $0, $1", "=e,e"
  __asm__("mov.u %0, %1" : "=e"(result) : "e"(x));
  return result;
}

// Generic register constraint 'r' (defaults to data register)
int test_generic_reg(int x) {
  int result;
  // CHECK-LABEL: @test_generic_reg
  // CHECK: call i32 asm "mov $0, $1", "=r,r"
  __asm__("mov %0, %1" : "=r"(result) : "r"(x));
  return result;
}

// Clobbers test
int test_clobbers(int a, int b) {
  int result;
  // CHECK-LABEL: @test_clobbers
  // CHECK: call i32 asm "add $0, $1, $2", "=d,d,d,~{d3},~{d4}"
  __asm__("add %0, %1, %2" : "=d"(result) : "d"(a), "d"(b) : "d3", "d4");
  return result;
}

// Memory constraint
void test_memory(int *ptr) {
  int value = 42;
  // CHECK-LABEL: @test_memory
  // CHECK: call void asm sideeffect "st.w [$0], $1", "a,d,~{memory}"
  __asm__ volatile ("st.w [%0], %1" : : "a"(ptr), "d"(value) : "memory");
}

// Early clobber
int test_early_clobber(int x) {
  int result;
  // CHECK-LABEL: @test_early_clobber
  // CHECK: call i32 asm "add $0, $1, $1", "=&d,d"
  __asm__("add %0, %1, %1" : "=&d"(result) : "d"(x));
  return result;
}
