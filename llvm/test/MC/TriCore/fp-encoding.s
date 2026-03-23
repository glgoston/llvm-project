; RUN: llvm-mc --arch tricore -mcpu=tc162 --show-encoding %s | FileCheck %s

; TC1.6 native floating-point instruction encoding tests.
; All FP instructions are in the RR (2-register) or RRR (3-register) format
; and only exist on CPUs with FeatureFP (tc162+).

; --- Arithmetic ---

        add.f D2, D4, D5
; CHECK: add.f %d2, %d4, %d5
; CHECK: encoding: [0x6b,0x54,0x22,0x20]

        sub.f D2, D4, D5
; CHECK: sub.f %d2, %d4, %d5
; CHECK: encoding: [0x6b,0x54,0x32,0x20]

        mul.f D2, D4, D5
; CHECK: mul.f %d2, %d4, %d5
; CHECK: encoding: [0x4b,0x54,0x42,0x20]

        div.f D2, D4, D5
; CHECK: div.f %d2, %d4, %d5
; CHECK: encoding: [0x4b,0x54,0x52,0x20]

; --- Compare ---

        cmp.f D15, D4, D5
; CHECK: cmp.f %d15, %d4, %d5
; CHECK: encoding: [0x4b,0x54,0x12,0xf0]

; --- Type conversions (unary; s2 field is zero) ---

        itof D2, D4
; CHECK: itof %d2, %d4
; CHECK: encoding: [0x4b,0x24,0x82,0x21]

        utof D2, D4
; CHECK: utof %d2, %d4
; CHECK: encoding: [0x4b,0x24,0x92,0x21]

        ftoiz D2, D4
; CHECK: ftoiz %d2, %d4
; CHECK: encoding: [0x4b,0x24,0x52,0x21]

        ftouz D2, D4
; CHECK: ftouz %d2, %d4
; CHECK: encoding: [0x4b,0x24,0x72,0x21]

; --- Reciprocal sqrt seed (unary) ---

        qseed.f D2, D4
; CHECK: qseed.f %d2, %d4
; CHECK: encoding: [0x4b,0x24,0x62,0x20]

; --- Fused multiply-add/sub (RRR format: d, s3, s1, s2) ---

        madd.f D2, D6, D4, D5
; CHECK: madd.f %d2, %d6, %d4, %d5
; CHECK: encoding: [0x43,0x54,0x62,0x26]

        msub.f D2, D6, D4, D5
; CHECK: msub.f %d2, %d6, %d4, %d5
; CHECK: encoding: [0x43,0x54,0x62,0x27]
