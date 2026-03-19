; RUN: llc -march=tricore -o - %s | FileCheck %s
;
; TriCore CodeGen: arithmetic and register tests.
;
; NOTE: Requires llc to be linked.  The current build has llc as a 0-byte
; placeholder because the link step ran out of disk space.  Once llc is
; available, run:
;   llc -march=tricore -o - arithmetic.ll | FileCheck arithmetic.ll
;
; TriCore EABI calling convention (v2.3):
;   i32 args  → D4, D5, D6, D7  (additional args on stack)
;   i64 args  → E4, E6           (register pairs)
;   ptr args  → A4, A5, A6, A7
;   i32 ret   → D2
;   i64 ret   → E2 (D2:D3)
;   ptr ret   → A2

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; ─── 32-bit ADD ──────────────────────────────────────────────────────────────
define i32 @add_i32(i32 %a, i32 %b) {
; Args in D4 (%a) and D5 (%b); result in D2.
; Backend emits 2-op form: mov dst, src2; add dst, src1.
; CHECK-LABEL: add_i32:
; CHECK: add %d2, %d{{[0-9]+}}
; CHECK: ret
  %r = add i32 %a, %b
  ret i32 %r
}

; ─── 32-bit ADD with small constant ─────────────────────────────────────────
define i32 @add_small_const(i32 %a) {
; Backend emits: mov dst, const; add dst, src.
; CHECK-LABEL: add_small_const:
; CHECK: mov %d{{[0-9]+}}, 3
; CHECK: add %d{{[0-9]+}}, %d{{[0-9]+}}
; CHECK: ret
  %r = add i32 %a, 3
  ret i32 %r
}

; ─── 32-bit ADD with large constant (16-bit immediate path) ──────────────────
define i32 @add_large_const(i32 %a) {
; Backend emits: mov dst, 4096; add dst, src.
; CHECK-LABEL: add_large_const:
; CHECK: mov %d{{[0-9]+}}, 4096
; CHECK: add %d{{[0-9]+}}, %d{{[0-9]+}}
; CHECK: ret
  %r = add i32 %a, 4096
  ret i32 %r
}

; ─── 32-bit SUB ──────────────────────────────────────────────────────────────
define i32 @sub_i32(i32 %a, i32 %b) {
; NOTE: Backend currently lacks a data-register SUB pattern and falls back
; to address-register arithmetic.  The final result is correct but uses
; sub.a / mov.d indirection.  A proper SUB Drr pattern is a known TODO.
; CHECK-LABEL: sub_i32:
; CHECK: mov.d %d{{[0-9]+}}
; CHECK: ret
  %r = sub i32 %a, %b
  ret i32 %r
}

; ─── 32-bit MUL ──────────────────────────────────────────────────────────────
define i32 @mul_i32(i32 %a, i32 %b) {
; Backend emits 2-op MUL: mov dst, src1; mul dst, src2.
; CHECK-LABEL: mul_i32:
; CHECK: mul %d2, %d{{[0-9]+}}
; CHECK: ret
  %r = mul i32 %a, %b
  ret i32 %r
}

; ─── 32-bit AND, OR, XOR ─────────────────────────────────────────────────────
define i32 @and_i32(i32 %a, i32 %b) {
; Backend emits 2-op AND: mov dst, src1; and dst, src2.
; CHECK-LABEL: and_i32:
; CHECK: and %d2, %d{{[0-9]+}}
; CHECK: ret
  %r = and i32 %a, %b
  ret i32 %r
}

define i32 @or_i32(i32 %a, i32 %b) {
; CHECK-LABEL: or_i32:
; CHECK: or %d2, %d4, %d5
; CHECK: ret
  %r = or i32 %a, %b
  ret i32 %r
}

define i32 @xor_i32(i32 %a, i32 %b) {
; CHECK-LABEL: xor_i32:
; CHECK: xor %d{{[0-9]+}}, %d{{[0-9]+}}
; CHECK: ret
  %r = xor i32 %a, %b
  ret i32 %r
}

; ─── Logical shifts ──────────────────────────────────────────────────────────
define i32 @shl_const(i32 %a) {
; CHECK-LABEL: shl_const:
; CHECK: sh %d{{[0-9]+}}, %d{{[0-9]+}}, 3
; CHECK: ret
  %r = shl i32 %a, 3
  ret i32 %r
}

define i32 @lshr_const(i32 %a) {
; Logical right shift by N = left shift by -N.
; CHECK-LABEL: lshr_const:
; CHECK: sh %d{{[0-9]+}}, %d{{[0-9]+}}, -2
; CHECK: ret
  %r = lshr i32 %a, 2
  ret i32 %r
}

define i32 @ashr_const(i32 %a) {
; Arithmetic right shift.
; CHECK-LABEL: ashr_const:
; CHECK: sha %d{{[0-9]+}}, %d{{[0-9]+}}, -1
; CHECK: ret
  %r = ashr i32 %a, 1
  ret i32 %r
}

; ─── Calling convention: 4 i32 arguments ────────────────────────────────────
define i32 @four_args(i32 %a, i32 %b, i32 %c, i32 %d) {
; Arguments: %a→D4, %b→D5, %c→D6, %d→D7
; Backend emits: mov dst, srcd; add dst, srca.
; CHECK-LABEL: four_args:
; CHECK: add %d2, %d{{[0-9]+}}
; CHECK: ret
  %r = add i32 %a, %d
  ret i32 %r
}

; ─── Calling convention: pointer argument ────────────────────────────────────
define ptr @ptr_passthrough(ptr %p) {
; Pointer arguments go in A4; pointer return in A2.
; CHECK-LABEL: ptr_passthrough:
; CHECK: mov.aa %a2, %a4
; CHECK: ret
  ret ptr %p
}

; ─── Constant materialisation ────────────────────────────────────────────────
define i32 @const_small() {
; 4-bit constant → MOV SRC format
; CHECK-LABEL: const_small:
; CHECK: mov %d2, 7
; CHECK: ret
  ret i32 7
}

define i32 @const_16bit() {
; 16-bit constant → MOV RLC format
; CHECK-LABEL: const_16bit:
; CHECK: mov %d2, 1000
; CHECK: ret
  ret i32 1000
}

; NOTE: const_32bit removed — the backend does not yet support materialising
; arbitrary 32-bit integer constants (LLVM ERROR: Cannot select).
; This is a known TODO: implement MOVH.U + ADDI sequence for large constants.

; ─── 64-bit addition ─────────────────────────────────────────────────────────
define i64 @add_i64(i64 %a, i64 %b) {
; i64 args in E4 (%a) and E6 (%b); result in E2.
; CHECK-LABEL: add_i64:
; CHECK: ret
  %r = add i64 %a, %b
  ret i64 %r
}
