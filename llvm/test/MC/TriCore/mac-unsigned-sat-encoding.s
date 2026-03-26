; RUN: llvm-mc --arch tricore -mcpu=tc2x --show-encoding %s | FileCheck %s

        madds.u D2, D4, D5, D6
; CHECK: madds.u %d2, %d4, %d5, %d6
; CHECK: encoding: [0x03,0x65,0x88,0x24]

        msubs.u D2, D4, D5, D6
; CHECK: msubs.u %d2, %d4, %d5, %d6
; CHECK: encoding: [0x23,0x65,0x88,0x24]
