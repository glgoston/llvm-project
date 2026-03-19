; RUN: llc -march=tricore -o - %s | FileCheck %s
;
; TriCore CodeGen: control flow tests (if / select / loop / switch).

target datalayout = "e-m:e-p:32:32-i64:32-a:0:32-n32"
target triple = "tricore"

; ─── Simple if-then-else: icmp sgt ──────────────────────────────────────────
define i32 @max_i32(i32 %a, i32 %b) {
; CHECK-LABEL: max_i32:
; Expect a conditional branch or a conditional-move equivalent.
; CHECK: {{j[a-z]+|sel}}
; CHECK: ret
  %cmp = icmp sgt i32 %a, %b
  %r   = select i1 %cmp, i32 %a, i32 %b
  ret i32 %r
}

; ─── icmp eq ────────────────────────────────────────────────────────────────
define i32 @is_zero(i32 %a) {
; Returns 1 if %a == 0, else 0.
; Backend emits: eq dst, src, 0; jnz dst, taken.
; CHECK-LABEL: is_zero:
; CHECK: eq %d{{[0-9]+}}, %d{{[0-9]+}}, 0
; CHECK: {{jnz|jz}}
; CHECK: ret
  %cmp = icmp eq i32 %a, 0
  %r   = zext i1 %cmp to i32
  ret i32 %r
}

; ─── icmp ne ────────────────────────────────────────────────────────────────
define i32 @is_nonzero(i32 %a) {
; Backend emits: ne dst, src, 0; jnz dst, taken.
; CHECK-LABEL: is_nonzero:
; CHECK: ne %d{{[0-9]+}}, %d{{[0-9]+}}, 0
; CHECK: {{jnz|jz}}
; CHECK: ret
  %cmp = icmp ne i32 %a, 0
  %r   = zext i1 %cmp to i32
  ret i32 %r
}

; ─── icmp ult (unsigned less than) ──────────────────────────────────────────
define i32 @unsigned_lt(i32 %a, i32 %b) {
; Backend emits: lt dst, src1, src2; jnz dst, taken.
; CHECK-LABEL: unsigned_lt:
; CHECK: {{lt|ge}} %d{{[0-9]+}}
; CHECK: {{jnz|jz}}
; CHECK: ret
  %cmp = icmp ult i32 %a, %b
  %r   = zext i1 %cmp to i32
  ret i32 %r
}

; ─── Simple while loop ──────────────────────────────────────────────────────
define i32 @sum_1_to_n(i32 %n) {
; sum = 0; i = 1; while (i <= n) { sum += i; i++; }  return sum;
; NOTE: Back-edge conditional branch emit is a known TODO in the TriCore backend.
; CHECK-LABEL: sum_1_to_n:
; CHECK: {{ge|lt}}
; CHECK: ret
entry:
  br label %loop
loop:
  %i   = phi i32 [ 1, %entry ], [ %i1, %loop ]
  %sum = phi i32 [ 0, %entry ], [ %sum1, %loop ]
  %sum1 = add i32 %sum, %i
  %i1   = add i32 %i, 1
  %cmp  = icmp sle i32 %i1, %n
  br i1 %cmp, label %loop, label %exit
exit:
  ret i32 %sum1
}

; ─── Switch with several cases ───────────────────────────────────────────────
define i32 @switch_example(i32 %x) {
; CHECK-LABEL: switch_example:
; CHECK: ret
entry:
  switch i32 %x, label %default [
    i32 0, label %case0
    i32 1, label %case1
    i32 2, label %case2
  ]
case0:
  ret i32 100
case1:
  ret i32 200
case2:
  ret i32 300
default:
  ret i32 0
}

; ─── Nested branches ─────────────────────────────────────────────────────────
define i32 @clamp(i32 %val, i32 %lo, i32 %hi) {
; return val < lo ? lo : (val > hi ? hi : val)
; CHECK-LABEL: clamp:
; CHECK: ret
  %lt = icmp slt i32 %val, %lo
  %s1 = select i1 %lt,  i32 %lo,  i32 %val
  %gt = icmp sgt i32 %s1, %hi
  %r  = select i1 %gt,  i32 %hi,  i32 %s1
  ret i32 %r
}

; ─── Early return / multiple exits ──────────────────────────────────────────
define i32 @abs_val(i32 %x) {
; if (x < 0) return -x; return x;
; CHECK-LABEL: abs_val:
; CHECK: ret
  %neg = icmp slt i32 %x, 0
  br i1 %neg, label %negate, label %done
negate:
  %nx = sub i32 0, %x
  ret i32 %nx
done:
  ret i32 %x
}
