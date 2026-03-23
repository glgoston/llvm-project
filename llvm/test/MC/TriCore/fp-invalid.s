; RUN: not llvm-mc -triple tricore-unknown-elf -mcpu=tc162 %s -o /dev/null 2>&1 | FileCheck %s

; Negative tests: FP instructions reject address-register (A-reg) operands
; and reject wrong operand counts.

; dest must be a DataReg, not an AddressReg
        add.f A2, D4, D5
; CHECK: error: invalid operand for instruction

; source operand must be a DataReg
        add.f D2, A4, D5
; CHECK: error: invalid operand for instruction

        sub.f D2, D4, A5
; CHECK: error: invalid operand for instruction

        qseed.f A2, D4
; CHECK: error: invalid operand for instruction

        itof A2, D4
; CHECK: error: invalid operand for instruction

; wrong operand count (too few)
        add.f D2, D4
; CHECK: error: too few operands for instruction

        madd.f D2, D4, D5
; CHECK: error: too few operands for instruction
