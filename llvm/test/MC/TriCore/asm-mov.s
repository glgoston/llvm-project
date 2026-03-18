; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore MOV instruction encoding tests.
;
; NOTE: Requires AsmParser operand parsing to be implemented first.
;
; MOV instruction variants:
;   MOVsrc   – SRC<0x82>  16-bit: move 4-bit signed immediate to data reg
;   MOVrlc   – RLC<0x3B>  32-bit: move 16-bit signed immediate to data reg
;   MOVUrlc  – RLC<0xBB>  32-bit: move 16-bit unsigned immediate to data reg
;   MOVHrlc  – RLC<0x7B>  32-bit: load 16-bit immediate into upper half of reg
;   MOVrr    – RR <0x0B, 0x1F>  data→data register copy
;   MOVArr   – RR <0x01, 0x63>  data reg → address reg
;   MOVDrr   – RR <0x01, 0x4C>  address reg → data reg
;   MOVAArr  – RR <0x01, 0x00>  address reg → address reg
;   MOVAAsrr – SRR<0x40>        address reg → address reg (16-bit)

; ─── MOV D2, 7 (SRC) ─────────────────────────────────────────────────────────
; SRC<0x82>: op1=0x82, d=D2(2), const4=7
; Encoding: const4=7(0111) d=D2(0010) op1=82 → bits: 0111 0010 1000 0010
; bytes: 0x82, 0x72
        mov D2, 7
; CHECK: mov D2, 7
; CHECK: encoding: [0x82,0x72]

; ─── MOV D2, -1 (SRC – negative immediate) ───────────────────────────────────
; const4=-1=0b1111, d=D2(2)
; bytes: 0x82, 0xF2
        mov D2, -1
; CHECK: mov D2, -1
; CHECK: encoding: [0x82,0xf2]

; ─── MOV D2, 0x1234 (RLC signed) ─────────────────────────────────────────────
; RLC<0x3B>: d=D2(2), s1=0, const16=0x1234, op1=0x3B
; bits[31:28]=0010 bits[27:12]=0001001000110100 bits[11:8]=0000 bits[7:0]=00111011
; = 0x2123_403B → bytes: 0x3B, 0x40, 0x23, 0x21
        mov D2, 0x1234
; CHECK: mov D2, 4660
; CHECK: encoding: [0x3b,0x40,0x23,0x21]

; ─── MOV.U D2, 0x8000 (RLC unsigned) ─────────────────────────────────────────
; RLC<0xBB>: d=D2(2), s1=0, const16=0x8000
; bits[31:28]=0010 bits[27:12]=1000000000000000 bits[11:8]=0000 bits[7:0]=10111011
; = 0x2800_00BB → bytes: 0xBB, 0x00, 0x00, 0x28
        mov.u D2, 0x8000
; CHECK: mov.u D2, 32768
; CHECK: encoding: [0xbb,0x00,0x00,0x28]

; ─── MOVH D2, 0xABCD (RLC – load upper half) ─────────────────────────────────
; RLC<0x7B>: d=D2(2), s1=0, const16=0xABCD
; bits[31:28]=0010 bits[27:12]=1010101111001101 bits[11:8]=0000 bits[7:0]=01111011
; = 0x2ABC_D07B → bytes: 0x7B, 0xD0, 0xBC, 0x2A
        movh D2, 0xABCD
; CHECK: movh D2, 43981
; CHECK: encoding: [0x7b,0xd0,0xbc,0x2a]

; ─── MOV D2, D3 (RR – data-to-data) ─────────────────────────────────────────
; RR<0x0B, 0x1F>: d=D2(2), op2=0x1F, n=0, s2=0, s1=D3(3), op1=0x0B
; bits[31:28]=0010 bits[27:20]=00011111 bits[15:12]=0000 bits[11:8]=0011 bits[7:0]=00001011
; = 0x201F030B → bytes: 0x0B, 0x03, 0x1F, 0x20
        mov D2, D3
; CHECK: mov D2, D3
; CHECK: encoding: [0x0b,0x03,0x1f,0x20]

; ─── MOV.A A4, D5 (RR – data-to-address) ────────────────────────────────────
        mov.a A4, D5
; CHECK: mov.a A4, D5

; ─── MOV.D D2, A3 (RR – address-to-data) ────────────────────────────────────
        mov.d D2, A3
; CHECK: mov.d D2, A3

; ─── MOV.AA A4, A5 (RR – address-to-address, 32-bit) ────────────────────────
        mov.aa A4, A5
; CHECK: mov.aa A4, A5

; ─── MOV.AA A4, A5 (SRR – address-to-address, 16-bit) ───────────────────────
; SRR<0x40>: op1=0x40, d=A4(4), s2=A5(5)
; bits: s2=0101 d=0100 op1=01000000 = 0x5440
; bytes: 0x40, 0x54
        mov.aa A4, A5
; (This line duplicates the 32-bit form above; the 16-bit form may be
;  selected by the assembler when the 16-bit encoding is preferred.)
; CHECK-LABEL encoding: [0x40,0x54]
