; RUN: llc -march=tricore -mcpu=tc2x -o - %s | FileCheck %s --check-prefix=TC2X
; RUN: llc -march=tricore -mcpu=tc18 -o - %s | FileCheck %s --check-prefix=NO-MAC

declare i32 @llvm.tricore.abss.i32(i32)
declare i32 @llvm.tricore.abssh.i32(i32)

; --- ABSS: saturating absolute (tc2x → hardware, other → select+abs) ---

define i32 @test_abss(i32 %x) {
entry:
  %r = call i32 @llvm.tricore.abss.i32(i32 %x)
  ret i32 %r
}

; TC2X-LABEL: test_abss:
; TC2X: abss %d2, %d4
; TC2X: ret

; NO-MAC-LABEL: test_abss:
; NO-MAC-NOT: abss %
; NO-MAC: abs
; NO-MAC: ret

; --- ABSS.H: halfword-packed saturating absolute (tc2x → hardware) ---

define i32 @test_abssh(i32 %x) {
entry:
  %r = call i32 @llvm.tricore.abssh.i32(i32 %x)
  ret i32 %r
}

; TC2X-LABEL: test_abssh:
; TC2X: abss.h %d2, %d4
; TC2X: ret
