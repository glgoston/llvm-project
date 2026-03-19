; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore MOV instruction encoding tests.
;
; MOV instruction variants:
;   MOVrlc   – RLC<0x3B>  32-bit: move 16-bit signed immediate to data reg
;   MOVUrlc  – RLC<0xBB>  32-bit: move 16-bit unsigned immediate to data reg
;   MOVHrlc  – RLC<0x7B>  32-bit: load 16-bit immediate into upper half of reg
;   MOVrr    – RR <0x0B, 0x1F>  data→data register copy
;   MOVArr   – RR <0x01, 0x63>  data reg → address reg
;   MOVDrr   – RR <0x01, 0x4C>  address reg → data reg
;   MOVAArr  – RR <0x01, 0x00>  address reg → address reg

; ─── MOV D2, 7 (RLC) ─────────────────────────────────────────────────────────
; RLC<0x3B>: d=D2(2), const16=7, s1=0, op1=0x3B
; bytes: 0x3b,0x72,0x00,0x20
        mov D2, 7
; CHECK: mov %d2, 7
; CHECK: encoding: [0x3b,0x72,0x00,0x20]

; ─── MOV D2, -1 (RLC – negative immediate) ───────────────────────────────────
        mov D2, -1
; CHECK: mov %d2, -1
; CHECK: encoding: [0x3b,0xf2,0xff,0x2f]

; ─── MOV D2, 0x1234 (RLC signed 16-bit immediate) ────────────────────────────
; RLC<0x3B>: d=D2(2), s1=0, const16=0x1234
        mov D2, 0x1234
; CHECK: mov %d2, 4660
; CHECK: encoding: [0x3b,0x42,0x23,0x21]

; ─── MOV.U D2, 0x8000 (RLC unsigned) ─────────────────────────────────────────
; RLC<0xBB>: d=D2(2), s1=0, const16=0x8000
        mov.u D2, 0x8000
; CHECK: mov.u %d2, 32768
; CHECK: encoding: [0xbb,0x02,0x00,0x28]

; ─── MOVH D2, 0xABCD (RLC – load upper half) ─────────────────────────────────
; RLC<0x7B>: d=D2(2), s1=0, const16=0xABCD
        movh D2, 0xABCD
; CHECK: movh %d2, 43981
; CHECK: encoding: [0x7b,0xd2,0xbc,0x2a]

; ─── MOV D2, D3 (RR – data-to-data) ─────────────────────────────────────────
; RR<0x0B, 0x1F>: d=D2(2), op2=0x1F, s1=D3(3)
        mov D2, D3
; CHECK: mov %d2, %d3
; CHECK: encoding: [0x0b,0x32,0xf3,0x21]

; ─── MOV.A A4, D5 (RR – data-to-address) ────────────────────────────────────
        mov.a A4, D5
; CHECK: mov.a %a4, %d5
; CHECK: encoding: [0x01,0x54,0x31,0x46]

; ─── MOV.D D2, A3 (RR – address-to-data) ────────────────────────────────────
        mov.d D2, A3
; CHECK: mov.d %d2, %a3
; CHECK: encoding: [0x01,0x32,0xc3,0x24]

; ─── MOV.AA A4, A5 (RR – address-to-address, 32-bit) ────────────────────────
        mov.aa A4, A5
; CHECK: mov.aa %a4, %a5
; CHECK: encoding: [0x01,0x54,0x01,0x40]

