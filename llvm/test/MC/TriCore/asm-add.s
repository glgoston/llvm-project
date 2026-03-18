; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore arithmetic instruction encoding tests.
;
; NOTE: These tests require the AsmParser operand parsing to be fully
; implemented (ParseInstruction in TriCoreAsmParser.cpp).  Until then
; each instruction below will produce "unexpected token parsing operands".
;
; Instruction format reference (TriCore v1.6 Architecture Manual):
;
;   RR  format (32-bit): <d[31:28] | op2[27:20] | -[19:18] | n[17:16] | s2[15:12] | s1[11:8] | op1[7:0]>
;   RC  format (32-bit): <d[31:28] | op2[27:21] | const9[20:12] | s1[11:8] | op1[7:0]>
;   RLC format (32-bit): <d[31:28] | const16[27:12] | s1[11:8] | op1[7:0]>
;   SRC format (16-bit): <const4[15:12] | d[11:8] | op1[7:0]>
;   SRR format (16-bit): <s2[15:12] | d[11:8] | op1[7:0]>

; ─── ADD (SRC) ────────────────────────────────────────────────────────────────
; SRC<0xC2>: op1=0xC2, d=2, const4=5
; Encoding: const4=5 → bits[15:12]=0101, d=D2 → bits[11:8]=0010, op1=0xC2
; Byte stream (little-endian): 0xC2, 0x52
        add D2, 5
; CHECK: add D2, 5
; CHECK: encoding: [0xc2,0x52]

; ─── ADD (RR) ─────────────────────────────────────────────────────────────────
; RR<0x0B, 0x00>: d=D2(2), op2=0x00, n=0, s2=D4(4), s1=D3(3), op1=0x0B
; Bits: d=0010 op2=00000000 00 n=00 s2=0100 s1=0011 op1=00001011
; = 0x2000430B  → bytes: 0x0B 0x43 0x00 0x20
        add D2, D3, D4
; CHECK: add D2, D3, D4
; CHECK: encoding: [0x0b,0x43,0x00,0x20]

; ─── ADD (RC) ─────────────────────────────────────────────────────────────────
; RC<0x8B, 0x00>: d=D2(2), op2=0x00(7-bit, bits[27:21]), const9=42, s1=D3(3), op1=0x8B
; const9=42=0x02A, op2=0b0000000
; Bits: d=0010 op2=0000000 const9=000101010 s1=0011 op1=10001011
; = 0x2000_2A38B? Let me express manually:
; bits[31:28]=0010, bits[27:21]=0000000, bits[20:12]=000101010, bits[11:8]=0011, bits[7:0]=10001011
; = 0010 0000 0000 0001 0101 0011 1000 1011 = 0x200153_8B
; bytes: 0x8B, 0x53, 0x01, 0x20  (but verify with actual assembler output)
        add D2, D3, 42
; CHECK: add D2, D3, 42
; CHECK: encoding: [0x8b,0x53,0x01,0x20]

; ─── ADDI (RLC) ───────────────────────────────────────────────────────────────
; RLC<0x1B>: d=D2(2), const16=0x1000, s1=D3(3), op1=0x1B
; bits[31:28]=0010, bits[27:12]=0001000000000000, bits[11:8]=0011, bits[7:0]=00011011
; = 0x2100 031B → bytes: 0x1B, 0x03, 0x00, 0x21
        addi D2, D3, 0x1000
; CHECK: addi D2, D3, 4096
; CHECK: encoding: [0x1b,0x03,0x00,0x21]

; ─── SUB (RR) ─────────────────────────────────────────────────────────────────
; RR<0x0B, 0x08>: d=D2(2), op2=0x08, n=0, s2=D4(4), s1=D3(3), op1=0x0B
; bits[31:28]=0010, bits[27:20]=00001000, bits[15:12]=0100, bits[11:8]=0011, bits[7:0]=00001011
; = 0x2008430B → bytes: 0x0B, 0x43, 0x08, 0x20
        sub D2, D3, D4
; CHECK: sub D2, D3, D4
; CHECK: encoding: [0x0b,0x43,0x08,0x20]

; ─── MUL (RR2) ────────────────────────────────────────────────────────────────
; RR2<0x73, 0x00A>: d=D2(2), op2(12-bit)=0x00A, s2=D4(4), s1=D3(3), op1=0x73
; bits[31:28]=0010, bits[27:16]=000000001010, bits[15:12]=0100, bits[11:8]=0011, bits[7:0]=01110011
; = 0x200A4373 → bytes: 0x73, 0x43, 0x0A, 0x20
        mul D2, D3, D4
; CHECK: mul D2, D3, D4
; CHECK: encoding: [0x73,0x43,0x0a,0x20]

; ─── AND (RR) ─────────────────────────────────────────────────────────────────
        and D2, D3, D4
; CHECK: and D2, D3, D4

; ─── OR (RR) ──────────────────────────────────────────────────────────────────
        or D2, D3, D4
; CHECK: or D2, D3, D4

; ─── XOR (SRR) ────────────────────────────────────────────────────────────────
        xor D2, D3
; CHECK: xor D2, D3

; ─── NOT (SR) ─────────────────────────────────────────────────────────────────
        not D2, D3
; CHECK: not D2, D3

; ─── SH (RC) ──────────────────────────────────────────────────────────────────
; Logical shift left by constant
        sh D2, D3, 3
; CHECK: sh D2, D3, 3

; ─── SHA (RC) ─────────────────────────────────────────────────────────────────
; Arithmetic shift right by constant (negative count = right shift)
        sha D2, D3, -1
; CHECK: sha D2, D3, -1

; ─── ADDC (RR, PSW) ───────────────────────────────────────────────────────────
; Add with carry – reads and writes PSW
        addc D2, D3, D4
; CHECK: addc D2, D3, D4

; ─── SUB.A (SC) ───────────────────────────────────────────────────────────────
; Adjust stack pointer: A10 -= const8
; SC<0x20>: op1=0x20, const8=8 → bytes: 0x20, 0x08
        sub.a %a10, 8
; CHECK: sub.a %a10, 8
; CHECK: encoding: [0x20,0x08]
