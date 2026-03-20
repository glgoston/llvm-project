; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

%pair = type { i32, i32 }

@G = global %pair zeroinitializer, align 4

define %pair @make_pair(i32 %a, i32 %b) {
; CHECK-LABEL: make_pair:
; CHECK: mov.a %a2, %d4
; CHECK: st.w [%a2] 4, %d6
; CHECK: st.w [%a2] 0, %d5
; CHECK: ret
  %p0 = insertvalue %pair undef, i32 %a, 0
  %p1 = insertvalue %pair %p0, i32 %b, 1
  ret %pair %p1
}

define i32 @sum_pair(%pair %p) {
; CHECK-LABEL: sum_pair:
; CHECK: add %d2, %d4
; CHECK: ret
  %a = extractvalue %pair %p, 0
  %b = extractvalue %pair %p, 1
  %s = add i32 %a, %b
  ret i32 %s
}

define void @store_pair(i32 %a, i32 %b) {
; CHECK-LABEL: store_pair:
; CHECK: st.w  4, %d5
; CHECK: st.w  0, %d4
; CHECK: ret
  %p0 = insertvalue %pair undef, i32 %a, 0
  %p1 = insertvalue %pair %p0, i32 %b, 1
  store %pair %p1, ptr @G, align 4
  ret void
}