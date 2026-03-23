; RUN: llc -march=tricore -mcpu=tc18 -o - %s | FileCheck %s --check-prefix=HW
; RUN: llc -march=tricore -mcpu=tc162 -o - %s | FileCheck %s --check-prefix=SOFT

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i32 @sdiv_i32(i32 %a, i32 %b) {
; HW-LABEL: sdiv_i32:
; HW: div %d2, %d4, %d5
; HW: ret
;
; SOFT-LABEL: sdiv_i32:
; SOFT: call __divsi3
; SOFT: ret
  %r = sdiv i32 %a, %b
  ret i32 %r
}

define i32 @udiv_i32(i32 %a, i32 %b) {
; HW-LABEL: udiv_i32:
; HW: div.u %d2, %d4, %d5
; HW: ret
;
; SOFT-LABEL: udiv_i32:
; SOFT: call __udivsi3
; SOFT: ret
  %r = udiv i32 %a, %b
  ret i32 %r
}
