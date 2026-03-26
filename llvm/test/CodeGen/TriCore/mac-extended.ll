; RUN: llc -mtriple=tricore -mcpu=tc2x  -verify-machineinstrs -o - %s \
; RUN:   | FileCheck %s --check-prefix=TC2X
; RUN: llc -mtriple=tricore -mcpu=tc18  -verify-machineinstrs -o - %s \
; RUN:   | FileCheck %s --check-prefix=NO-MAC

; Test TC1.6P extended (64-bit E-reg) and Q-format MAC intrinsic lowering.

declare i64 @llvm.tricore.maddu.i64(i64, i32, i32)
declare i64 @llvm.tricore.msubu.i64(i64, i32, i32)
declare i32 @llvm.tricore.maddq.i32(i32, i32, i32)
declare i32 @llvm.tricore.msubq.i32(i32, i32, i32)

; --- Extended unsigned MAC (64-bit E-reg result) ---

; TC2X: test_maddu_i64:
; TC2X: madd.u
; NO-MAC: test_maddu_i64:
; NO-MAC-NOT: madd.u
define i64 @test_maddu_i64(i64 %acc, i32 %x, i32 %y) nounwind {
  %r = call i64 @llvm.tricore.maddu.i64(i64 %acc, i32 %x, i32 %y)
  ret i64 %r
}

; TC2X: test_msubu_i64:
; TC2X: msub.u
; NO-MAC: test_msubu_i64:
; NO-MAC-NOT: msub.u
define i64 @test_msubu_i64(i64 %acc, i32 %x, i32 %y) nounwind {
  %r = call i64 @llvm.tricore.msubu.i64(i64 %acc, i32 %x, i32 %y)
  ret i64 %r
}

; --- Q-format fractional MAC (32-bit D-reg result) ---

; TC2X: test_maddq_i32:
; TC2X: madd.q
; NO-MAC: test_maddq_i32:
; NO-MAC-NOT: madd.q
; NO-MAC: mul
define i32 @test_maddq_i32(i32 %acc, i32 %x, i32 %y) nounwind {
  %r = call i32 @llvm.tricore.maddq.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

; TC2X: test_msubq_i32:
; TC2X: msub.q
; NO-MAC: test_msubq_i32:
; NO-MAC-NOT: msub.q
; NO-MAC: mul
define i32 @test_msubq_i32(i32 %acc, i32 %x, i32 %y) nounwind {
  %r = call i32 @llvm.tricore.msubq.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}
