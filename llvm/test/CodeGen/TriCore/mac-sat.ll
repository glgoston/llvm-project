; RUN: llc -march=tricore -mcpu=tc2x -o - %s | FileCheck %s --check-prefix=TC2X

declare i32 @llvm.sadd.sat.i32(i32, i32)
declare i32 @llvm.ssub.sat.i32(i32, i32)

define i32 @sat_add_i32(i32 %a, i32 %b) {
entry:
  %r = call i32 @llvm.sadd.sat.i32(i32 %a, i32 %b)
  ret i32 %r
}

define i32 @sat_sub_i32(i32 %a, i32 %b) {
entry:
  %r = call i32 @llvm.ssub.sat.i32(i32 %a, i32 %b)
  ret i32 %r
}

; TC2X-LABEL: sat_add_i32:
; TC2X: adds %d2, %d4, %d5
; TC2X: ret

; TC2X-LABEL: sat_sub_i32:
; TC2X: subs %d2, %d4, %d5
; TC2X: ret
