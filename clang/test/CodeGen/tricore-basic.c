// RUN: %clang -target tricore-unknown-elf -S -o - %s | FileCheck %s
// RUN: %clang -target tricore-unknown-elf -mcpu=tc162 -S -o - %s | FileCheck %s --check-prefix=CPU

extern int ext(int);
int Glob;

int add_two(int a, int b) {
  return a + b;
}

int sub_two(int a, int b) {
  return a - b;
}

int call_ext(int x) {
  return ext(x + 1);
}

int read_global(void) {
  return Glob;
}

void write_global(int x) {
  Glob = x;
}

// CHECK-LABEL: add_two:
// CHECK: add
// CHECK: ret

// CHECK-LABEL: sub_two:
// CHECK: sub
// CHECK: ret

// CHECK-LABEL: call_ext:
// CHECK: call
// CHECK: ret

// CHECK-LABEL: read_global:
// CHECK: ld.w

// CHECK-LABEL: write_global:
// CHECK: st.w

// CPU-LABEL: add_two:
// CPU: add