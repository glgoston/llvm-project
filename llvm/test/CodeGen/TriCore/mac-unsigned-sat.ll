; RUN: llc -march=tricore -mcpu=tc2x -o - %s | FileCheck %s --check-prefix=TC2X
; RUN: llc -march=tricore -mcpu=tc18 -o - %s | FileCheck %s --check-prefix=NO-MAC

declare i32 @llvm.tricore.maddsu.i32(i32, i32, i32)
declare i32 @llvm.tricore.msubsu.i32(i32, i32, i32)

define i32 @maddsu_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.maddsu.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

define i32 @msubsu_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.msubsu.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

; TC2X-LABEL: maddsu_i32:
; TC2X: madds.u %d2, %d4, %d5, %d6
; TC2X: ret

; TC2X-LABEL: msubsu_i32:
; TC2X: msubs.u %d2, %d4, %d5, %d6
; TC2X: ret

; NO-MAC-LABEL: maddsu_i32:
; NO-MAC-NOT: madds.u %
; NO-MAC: mul
; NO-MAC: add

; NO-MAC-LABEL: msubsu_i32:
; NO-MAC-NOT: msubs.u %
; NO-MAC: mul
; NO-MAC: sub
