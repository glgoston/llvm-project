; RUN: llvm-mc --arch tricore -mcpu=tc2x --show-encoding %s | FileCheck %s

        .text

        abss D2, D4
; CHECK: abss %d2, %d4
; CHECK: encoding: [0x0b,0x24,0xc0,0x25]

        abss.h D2, D4
; CHECK: abss.h %d2, %d4
; CHECK: encoding: [0x0b,0x24,0xd0,0x25]
