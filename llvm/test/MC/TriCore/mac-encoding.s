; RUN: llvm-mc --arch tricore -mcpu=tc2x --show-encoding %s | FileCheck %s

        adds D2, D3, D4
; CHECK: adds %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x22,0x20]

        adds.u D2, D3, D4
; CHECK: adds.u %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0x32,0x20]

        subs D2, D3, D4
; CHECK: subs %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0xa2,0x20]

        subs.u D2, D3, D4
; CHECK: subs.u %d2, %d3, %d4
; CHECK: encoding: [0x0b,0x43,0xb2,0x20]
