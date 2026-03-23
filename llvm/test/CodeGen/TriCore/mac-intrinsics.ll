; RUN: llc -march=tricore -mcpu=tc2x -o - %s | FileCheck %s --check-prefix=TC2X
; RUN: llc -march=tricore -mcpu=tc18 -o - %s | FileCheck %s --check-prefix=NO-MAC

declare i32 @llvm.tricore.madd.i32(i32, i32, i32)
declare i32 @llvm.tricore.msub.i32(i32, i32, i32)

define i32 @madd_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.madd.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

define i32 @msub_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.msub.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

; TC2X-LABEL: madd_i32:
; TC2X: madd %d2, %d4, %d5, %d6
; TC2X: ret

; TC2X-LABEL: msub_i32:
; TC2X: msub %d2, %d4, %d5, %d6
; TC2X: ret

; NO-MAC-LABEL: madd_i32:
; NO-MAC-NOT: madd %
; NO-MAC: mul
; NO-MAC: add

; NO-MAC-LABEL: msub_i32:
; NO-MAC-NOT: msub %
; NO-MAC: mul
; NO-MAC: sub
