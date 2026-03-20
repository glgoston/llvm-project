; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

define i64 @mul64(i64 %a, i64 %b) {
; CHECK-LABEL: mul64:
; CHECK: call __muldi3
; CHECK: ret
  %r = mul i64 %a, %b
  ret i64 %r
}