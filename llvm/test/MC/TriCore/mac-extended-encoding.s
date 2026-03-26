; RUN: llvm-mc -triple=tricore -mcpu=tc2x -show-encoding %s \
; RUN:   | FileCheck %s

; MADD.U / MSUB.U — RRR2 (op1=0x03/0x23, op2=0x68), E-reg result
; Encoding: [op1, s2:s1, op2, d:s3]   (little-endian bytes)

; madd.u e2, e4, D5, D6
;   bits[7:0]=0x03  bits[11:8]=s1=5(D5)  bits[15:12]=s2=6(D6)
;   bits[23:16]=0x68  bits[27:24]=s3=4(E4)  bits[31:28]=d=2(E2)
;   Bytes: [0x03, 0x65, 0x68, 0x24]
; CHECK: madd.u %e2, %e4, %d5, %d6
; CHECK-SAME: encoding: [0x03,0x65,0x68,0x24]
madd.u e2, e4, D5, D6

; msub.u e2, e4, D5, D6
;   Same as above but op1=0x23
;   Bytes: [0x23, 0x65, 0x68, 0x24]
; CHECK: msub.u %e2, %e4, %d5, %d6
; CHECK-SAME: encoding: [0x23,0x65,0x68,0x24]
msub.u e2, e4, D5, D6

; MADD.Q / MSUB.Q — RRR1 (op1=0x43/0x63, op2=0x02, n=1), D-reg result
; Encoding: [op1, s2:s1, op2-hi|n:op2-lo, d:s3]
;   bits[7:0]=op1  bits[11:8]=s1  bits[15:12]=s2
;   bits[17:16]=n=1=01b  bits[23:18]=op2=0x02=000010b
;   → byte2 = 0b00001001 = 0x09
;   bits[27:24]=s3  bits[31:28]=d

; madd.q D2, D4, D5, D6, 1
;   Bytes: [0x43, 0x65, 0x09, 0x24]
; CHECK: madd.q %d2, %d4, %d5, %d6, 1
; CHECK-SAME: encoding: [0x43,0x65,0x09,0x24]
madd.q D2, D4, D5, D6, 1

; msub.q D2, D4, D5, D6, 1
;   Bytes: [0x63, 0x65, 0x09, 0x24]
; CHECK: msub.q %d2, %d4, %d5, %d6, 1
; CHECK-SAME: encoding: [0x63,0x65,0x09,0x24]
msub.q D2, D4, D5, D6, 1
