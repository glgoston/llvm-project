; RUN: llc -march=tricore -o - %s | FileCheck %s
;
; TriCore CodeGen: calling convention tests.
;
; TriCore EABI v2.3 Calling Convention Summary
; ─────────────────────────────────────────────
; Argument registers:
;   i32 / i8 / i16 (zero/sign-extended to i32): D4, D5, D6, D7
;   i64 (register pairs):                        E4 (D4:D5), E6 (D6:D7)
;   Pointers:                                    A4, A5, A6, A7
;   Remaining arguments:                         stack (4-byte slots, 4-byte aligned)
;
; Return registers:
;   i32:     D2
;   i64:     E2  (D2:D3)
;   pointer: A2
;
; Callee-saved registers:
;   Data:    D8–D15
;   Address: A10 (SP), A11 (RA), A12–A15

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; ─── No arguments, no return value ──────────────────────────────────────────
define void @void_func() {
; CHECK-LABEL: void_func:
; CHECK: ret
  ret void
}

; ─── Single i32 argument / i32 return ───────────────────────────────────────
define i32 @identity_i32(i32 %a) {
; %a arrives in D4, must be returned in D2.
; CHECK-LABEL: identity_i32:
; CHECK: mov %d2, %d4
; CHECK: ret
  ret i32 %a
}

; ─── Two i32 arguments ───────────────────────────────────────────────────────
define i32 @add_two(i32 %a, i32 %b) {
; %a→D4, %b→D5, result→D2
; Backend emits 2-op form: mov dst, src2; add dst, src1.
; CHECK-LABEL: add_two:
; CHECK: add %d2, %d{{[0-9]+}}
; CHECK: ret
  %r = add i32 %a, %b
  ret i32 %r
}

; ─── Four i32 arguments (fills D4–D7) ───────────────────────────────────────
define i32 @sum_four(i32 %a, i32 %b, i32 %c, i32 %d) {
; CHECK-LABEL: sum_four:
; CHECK-DAG: add
; CHECK: ret
  %ab = add i32 %a, %b
  %cd = add i32 %c, %d
  %r  = add i32 %ab, %cd
  ret i32 %r
}

; ─── Fifth argument spills to stack ─────────────────────────────────────────
define i32 @five_args(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e) {
; The 5th argument (%e) is on the stack (ld.w from [A10]+offset).
; CHECK-LABEL: five_args:
; CHECK: ld.w %d{{[0-9]+}}, [%a10]
; CHECK: ret
  %ab = add i32 %a, %b
  %re = add i32 %e, %ab
  ret i32 %re
}

; ─── Pointer argument and return ────────────────────────────────────────────
define ptr @ptr_identity(ptr %p) {
; %p in A4, return in A2
; CHECK-LABEL: ptr_identity:
; CHECK: mov.aa %a2, %a4
; CHECK: ret
  ret ptr %p
}

; ─── i64 argument and return ─────────────────────────────────────────────────
define i64 @i64_identity(i64 %v) {
; %v in E4 (D4:D5), return in E2 (D2:D3)
; CHECK-LABEL: i64_identity:
; CHECK: ret
  ret i64 %v
}

; ─── Callee-saved: D8 must be preserved across a call ───────────────────────
define i32 @uses_callee_saved(i32 %a) {
; If the backend allocates D8 as a temp it must save/restore it.
; CHECK-LABEL: uses_callee_saved:
; CHECK-NOT: st.w {{.*}}%d8
; CHECK: ret
  %r = add i32 %a, 1
  ret i32 %r
}

; ─── Function that calls another function (needs RA save) ───────────────────
declare i32 @external(i32)

define i32 @calls_external(i32 %a) {
; Prologue must save A11 (return address) onto the stack.
; CHECK-LABEL: calls_external:
; CHECK: sub.a %a10,
; CHECK: call external
; CHECK: ret
  %r = call i32 @external(i32 %a)
  ret i32 %r
}

; ─── Mixed pointer and integer arguments ────────────────────────────────────
define i32 @load_and_add(ptr %p, i32 %offset) {
; %p in A4, %offset in D4 (note: first integer reg after pointers is still D4)
; CHECK-LABEL: load_and_add:
; CHECK: ld.w
; CHECK: add
; CHECK: ret
  %v = load i32, ptr %p
  %r = add i32 %v, %offset
  ret i32 %r
}

; ─── i8 / i16 promotion to i32 ───────────────────────────────────────────────
define i8 @add_i8(i8 %a, i8 %b) {
; i8 args are zero/sign-extended to i32 on entry.
; CHECK-LABEL: add_i8:
; CHECK: add
; CHECK: ret
  %r = add i8 %a, %b
  ret i8 %r
}
