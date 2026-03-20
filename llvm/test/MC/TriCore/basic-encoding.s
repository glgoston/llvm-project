; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s

        ret
; CHECK: ret
; CHECK: encoding: [0x00,0x90]

        add D2, 5
; CHECK: add %d2, 5
; CHECK: encoding: [0xc2,0x52]

        add D2, D3, D4
; CHECK: add %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x02,0x20]

        sub D2, D3, D4
; CHECK: sub %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x82,0x20]