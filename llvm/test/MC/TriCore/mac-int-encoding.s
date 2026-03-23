; RUN: llvm-mc --arch tricore -mcpu=tc2x --show-encoding %s | FileCheck %s

        madd D2, D4, D5, D6
; CHECK: madd %d2, %d4, %d5, %d6
; CHECK: encoding: [0x03,0x65,0x0a,0x24]

        msub D2, D4, D5, D6
; CHECK: msub %d2, %d4, %d5, %d6
; CHECK: encoding: [0x23,0x65,0x0a,0x24]
