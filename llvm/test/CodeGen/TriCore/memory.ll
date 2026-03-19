; RUN: llc -march=tricore -o - %s | FileCheck %s
;
; TriCore CodeGen: load, store, and stack (alloca) tests.

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; ─── 32-bit load from pointer argument ──────────────────────────────────────
define i32 @load_i32(ptr %p) {
; %p in A4; result in D2.
; CHECK-LABEL: load_i32:
; CHECK: ld.w %d2, [%a4]
; CHECK: ret
  %v = load i32, ptr %p
  ret i32 %v
}

; ─── 32-bit load with byte offset ────────────────────────────────────────────
define i32 @load_i32_offset(ptr %p) {
; Address is %p + 8.
; CHECK-LABEL: load_i32_offset:
; CHECK: ld.w %d2, [%a4] 8
; CHECK: ret
  %gep = getelementptr i32, ptr %p, i32 2
  %v   = load i32, ptr %gep
  ret i32 %v
}

; ─── 32-bit store ────────────────────────────────────────────────────────────
define void @store_i32(ptr %p, i32 %val) {
; %p in A4, %val in D4.
; CHECK-LABEL: store_i32:
; CHECK: st.w [%a4] 0, %d4
; CHECK: ret
  store i32 %val, ptr %p
  ret void
}

; ─── 8-bit load (sign-extended) ──────────────────────────────────────────────
define i32 @load_i8_sext(ptr %p) {
; CHECK-LABEL: load_i8_sext:
; CHECK: ld.b %d2, [%a4]
; CHECK: ret
  %v = load i8, ptr %p
  %e = sext i8 %v to i32
  ret i32 %e
}

; ─── 8-bit load (zero-extended) ──────────────────────────────────────────────
define i32 @load_i8_zext(ptr %p) {
; CHECK-LABEL: load_i8_zext:
; CHECK: ld.bu %d2, [%a4]
; CHECK: ret
  %v = load i8, ptr %p
  %e = zext i8 %v to i32
  ret i32 %e
}

; ─── 16-bit load (sign-extended) ─────────────────────────────────────────────
define i32 @load_i16_sext(ptr %p) {
; CHECK-LABEL: load_i16_sext:
; CHECK: ld.h %d2, [%a4]
; CHECK: ret
  %v = load i16, ptr %p
  %e = sext i16 %v to i32
  ret i32 %e
}

; ─── 16-bit load (zero-extended) ─────────────────────────────────────────────
define i32 @load_i16_zext(ptr %p) {
; CHECK-LABEL: load_i16_zext:
; CHECK: ld.hu %d2, [%a4]
; CHECK: ret
  %v = load i16, ptr %p
  %e = zext i16 %v to i32
  ret i32 %e
}

; ─── 8-bit store ─────────────────────────────────────────────────────────────
define void @store_i8(ptr %p, i8 %val) {
; CHECK-LABEL: store_i8:
; CHECK: st.b [%a4] 0, %d4
; CHECK: ret
  store i8 %val, ptr %p
  ret void
}

; ─── 16-bit store ────────────────────────────────────────────────────────────
define void @store_i16(ptr %p, i16 %val) {
; CHECK-LABEL: store_i16:
; CHECK: st.h [%a4] 0, %d4
; CHECK: ret
  store i16 %val, ptr %p
  ret void
}

; ─── 64-bit load ─────────────────────────────────────────────────────────────
define i64 @load_i64(ptr %p) {
; ld.d loads an even register pair (extended register).
; CHECK-LABEL: load_i64:
; CHECK: ld.d %e2, [%a4]
; CHECK: ret
  %v = load i64, ptr %p
  ret i64 %v
}

; ─── 64-bit store ────────────────────────────────────────────────────────────
define void @store_i64(ptr %p, i64 %v) {
; i64 arg in E4 (D4:D5); st.d stores even register pair.
; CHECK-LABEL: store_i64:
; CHECK: st.d [%a4] 0, %e4
; CHECK: ret
  store i64 %v, ptr %p
  ret void
}

; ─── Local i32 variable (alloca) ─────────────────────────────────────────────
define i32 @local_i32(i32 %a) {
; Frame must be allocated (sub.a %a10, N), variable stored then loaded.
; CHECK-LABEL: local_i32:
; CHECK: sub.a %a10,
; CHECK: st.w
; CHECK: ret
  %x = alloca i32, align 4
  store i32 %a, ptr %x
  %v = load i32, ptr %x
  ret i32 %v
}

; ─── Load-modify-store pattern ───────────────────────────────────────────────
define void @increment(ptr %p) {
; *p += 1
; CHECK-LABEL: increment:
; CHECK: ld.w
; CHECK: add
; CHECK: st.w
; CHECK: ret
  %v  = load i32, ptr %p
  %v1 = add i32 %v, 1
  store i32 %v1, ptr %p
  ret void
}

; ─── Array access via GEP ────────────────────────────────────────────────────
define i32 @array_element(ptr %arr, i32 %idx) {
; arr[idx]  — idx is a data register (D4 after %arr occupies A4).
; The backend must multiply idx by 4 (element size) and add to base pointer.
; CHECK-LABEL: array_element:
; CHECK: ld.w
; CHECK: ret
  %gep = getelementptr i32, ptr %arr, i32 %idx
  %v   = load i32, ptr %gep
  ret i32 %v
}
