; RUN: llc -march=tricore -mcpu=tc2x -o - %s | FileCheck %s --check-prefix=TC2X
; RUN: llc -march=tricore -mcpu=tc18 -o - %s | FileCheck %s --check-prefix=NO-MAC

declare i32 @llvm.tricore.madds.i32(i32, i32, i32)
declare i32 @llvm.tricore.msubs.i32(i32, i32, i32)

define i32 @madds_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.madds.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

define i32 @msubs_i32(i32 %acc, i32 %x, i32 %y) {
entry:
  %r = call i32 @llvm.tricore.msubs.i32(i32 %acc, i32 %x, i32 %y)
  ret i32 %r
}

; TC2X-LABEL: madds_i32:
; TC2X: madds %d2, %d4, %d5, %d6
; TC2X: ret

; TC2X-LABEL: msubs_i32:
; TC2X: msubs %d2, %d4, %d5, %d6
; TC2X: ret

; NO-MAC-LABEL: madds_i32:
; NO-MAC-NOT: madds %
; NO-MAC: call __muldi3

; NO-MAC-LABEL: msubs_i32:
; NO-MAC-NOT: msubs %
; NO-MAC: call __muldi3
