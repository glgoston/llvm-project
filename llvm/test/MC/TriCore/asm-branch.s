; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore branch, call and return instruction encoding tests.
;
; NOTE: Requires AsmParser operand parsing to be implemented first.
;
; Branch instruction formats:
;   B   format (32-bit): op1 + 24-bit displacement  (call / unconditional jump)
;   BRN format (32-bit): branch on data register bit
;   BRC format (32-bit): branch register-const compare
;   BRR format (32-bit): branch register-register compare
;   SB  format (16-bit): short branch (8-bit displacement)
;   SBR format (16-bit): short branch with register

; ─── Unconditional jump (B format, 32-bit, op1=0x1D) ─────────────────────────
; Displacement is PC-relative in units of 2 bytes (word offset).
        j target32
; CHECK: j target32

; ─── Short unconditional jump (SB format, 16-bit, op1=0xFC) ──────────────────
; 8-bit displacement, word-relative
        j target16
; CHECK: j target16

; ─── Jump if zero / not-zero on data register bit ────────────────────────────
; JNZ  BRN-like; checks one bit of a data register
        jnz D4, nonzero
; CHECK: jnz D4, nonzero

        jz D4, iszero
; CHECK: jz D4, iszero

; ─── Branch on comparison (BRC – register vs. constant) ──────────────────────
; These map to TriCore JEQ, JNE, JLT, JGE, etc.
        jeq D4, 0, equal
; CHECK: jeq D4, 0, equal

        jne D4, 3, notthree
; CHECK: jne D4, 3, notthree

        jlt D4, 5, lessthan5
; CHECK: jlt D4, 5, lessthan5

        jge D4, 10, atleast10
; CHECK: jge D4, 10, atleast10

; ─── Branch on comparison (BRR – register vs. register) ─────────────────────
        jeq D4, D5, same
; CHECK: jeq D4, D5, same

        jne D4, D5, differ
; CHECK: jne D4, D5, differ

; ─── Direct call (B format, op1=0x6D) ────────────────────────────────────────
        call external_func
; CHECK: call external_func

; ─── Indirect call (RR format, op1=0x2D, op2=0x00) ──────────────────────────
; Calls the function pointer held in an address register
        calli A4
; CHECK: calli A4

; ─── Return (T16 format, op1=0x00) ──────────────────────────────────────────
; The encoding is a fixed 16-bit value 0x0000.
        ret
; CHECK: ret
; CHECK: encoding: [0x00,0x00]

; ─── Dummy labels used above ────────────────────────────────────────────────
target32:
target16:
nonzero:
iszero:
equal:
notthree:
lessthan5:
atleast10:
same:
differ:
