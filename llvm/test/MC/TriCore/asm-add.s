; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore arithmetic instruction encoding tests.
;
; Instruction format reference (TriCore v1.6 Architecture Manual):
;
;   RR  format (32-bit): op1 | s1 | s2 | op2 | d
;   RC  format (32-bit): op1 | s1 | const9 | op2 | d
;   RLC format (32-bit): op1 | s1 | const16 | d
;   SRC format (16-bit): op1 | d | const4
;   SRR format (16-bit): op1 | d | s2

; ─── ADD (SRC) ────────────────────────────────────────────────────────────────
; SRC<0xC2>: op1=0xC2, d=2, const4=5
        add D2, 5
; CHECK: add %d2, 5
; CHECK: encoding: [0xc2,0x52]

; ─── ADD (RR) ─────────────────────────────────────────────────────────────────
; RR<0x0B, 0x00>: d=2, op2=0x00, s2=4, s1=3, op1=0x0B
        add D2, D3, D4
; CHECK: add %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x02,0x20]

; ─── ADD (RC) ─────────────────────────────────────────────────────────────────
; RC<0x8B, 0x00>: d=2, op2=0, const9=42, s1=3, op1=0x8B
        add D2, D3, 42
; CHECK: add %d2, %d3, 42
; CHECK: encoding: [0x8b,0xa3,0x02,0x20]

; ─── ADDI (RLC) ───────────────────────────────────────────────────────────────
; RLC<0x1B>: d=2, const16=0x1000, s1=3, op1=0x1B
        addi D2, D3, 0x1000
; CHECK: addi %d2, %d3, 4096
; CHECK: encoding: [0x1b,0x03,0x00,0x21]

; ─── SUB (RR) ─────────────────────────────────────────────────────────────────
; RR<0x0B, 0x08>: d=2, op2=0x08, s2=4, s1=3, op1=0x0B
        sub D2, D3, D4
; CHECK: sub %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x82,0x20]

; ─── MUL (RR2) ────────────────────────────────────────────────────────────────
        mul D2, D3, D4
; CHECK: mul %d2, %d3, %d4
; CHECK: encoding: [0x73,0x43,0x0a,0x20]

; ─── AND (RR) ─────────────────────────────────────────────────────────────────
        and D2, D3, D4
; CHECK: and %d2, %d3, %d4
; CHECK: encoding: [0x0f,0x43,0x82,0x20]

; ─── OR (RR) ──────────────────────────────────────────────────────────────────
        or D2, D3, D4
; CHECK: or %d2, %d3, %d4
; CHECK: encoding: [0x0f,0x43,0xa2,0x20]

; ─── XOR (RR) ─────────────────────────────────────────────────────────────────
        xor D2, D3, D4
; CHECK: xor %d2, %d3, %d4
; CHECK: encoding: [0x0f,0x43,0xc2,0x20]

; ─── NOT (SR) ─────────────────────────────────────────────────────────────────
        not D2
; CHECK: not %d2
; CHECK: encoding: [0x46,0x22]

; ─── SH (RC) ──────────────────────────────────────────────────────────────────
        sh D2, D3, 3
; CHECK: sh %d2, %d3, 3
; CHECK: encoding: [0x8f,0x33,0x00,0x20]

; ─── SHA (RC) ─────────────────────────────────────────────────────────────────
        sha D2, D3, -1
; CHECK: sha %d2, %d3, -1
; CHECK: encoding: [0x8f,0xf3,0x3f,0x20]

; ─── ADDC (RR, PSW) ───────────────────────────────────────────────────────────
        addc D2, D3, D4
; CHECK: addc %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x52,0x20]

