; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore branch, call and return instruction encoding tests.
;
; Branch instruction formats:
;   B   format (32-bit): op1 + 24-bit displacement  (call / unconditional jump)
;   BRC format (32-bit): branch register-const compare (15-bit disp, 4-bit const)
;   BRR format (32-bit): branch register-register compare (15-bit disp)
;   SBR format (16-bit): short branch with data register (4-bit disp)

; ─── Return (fixed encoding) ─────────────────────────────────────────────────
        ret
; CHECK: ret
; CHECK: encoding: [0x00,0x90]

; ─── Indirect call ────────────────────────────────────────────────────────────
        calli A4
; CHECK: calli %a4
; CHECK: encoding: [0x2d,0x04,0x00,0x00]

; ─── Unconditional jump (B format, 32-bit, op1=0x1D) ─────────────────────────
        j target
; CHECK: j target

; ─── Direct call (B format, op1=0x6D) ────────────────────────────────────────
        call target
; CHECK: call target

; ─── JNZ/JZ – 16-bit short branches (SBR format) ─────────────────────────────
        jnz D4, target
; CHECK: jnz %d4, target

        jz D4, target
; CHECK: jz %d4, target

; ─── BRC – 32-bit branch on comparison reg vs constant ───────────────────────
        jeq D4, 0, target
; CHECK: jeq %d4, 0, target

        jne D4, 3, target
; CHECK: jne %d4, 3, target

        jlt D4, 5, target
; CHECK: jlt %d4, 5, target

        jge D4, 7, target
; CHECK: jge %d4, 7, target

; ─── BRR – 32-bit branch on comparison reg vs reg ────────────────────────────
        jeq D4, D5, target
; CHECK: jeq %d4, %d5, target

        jne D4, D5, target
; CHECK: jne %d4, %d5, target

; ─── Dummy labels ─────────────────────────────────────────────────────────────
target:

