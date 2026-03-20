; RUN: llc -march=tricore -o - %s | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

@glob = global i32 7, align 4

define i32 @load_global() {
; CHECK-LABEL: load_global:
; CHECK: ld.w
; CHECK: ret
  %v = load i32, ptr @glob, align 4
  ret i32 %v
}

define void @store_global(i32 %v) {
; CHECK-LABEL: store_global:
; CHECK: st.w
; CHECK: ret
  store i32 %v, ptr @glob, align 4
  ret void
}