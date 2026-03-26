; RUN: llvm-mc --arch tricore -mcpu=tc2x --show-encoding %s | FileCheck %s

; MADDS/MSUBS — RRR2 (op1=0x03/0x23, op2=0x8A), signed saturating 32-bit D-reg result.
; Encoding: [op1, s2:s1, op2, d:s3]   (little-endian bytes)
;
; madds D2, D4, D5, D6
;   bits[7:0]=0x03  bits[11:8]=s1=5(D5)  bits[15:12]=s2=6(D6)
;   bits[23:16]=0x8A  bits[27:24]=s3=4(D4)  bits[31:28]=d=2(D2)
;   Bytes: [0x03, 0x65, 0x8A, 0x24]
        madds D2, D4, D5, D6
; CHECK: madds %d2, %d4, %d5, %d6
; CHECK-SAME: encoding: [0x03,0x65,0x8a,0x24]

; msubs D2, D4, D5, D6
;   Same as above but op1=0x23
;   Bytes: [0x23, 0x65, 0x8A, 0x24]
        msubs D2, D4, D5, D6
; CHECK: msubs %d2, %d4, %d5, %d6
; CHECK-SAME: encoding: [0x23,0x65,0x8a,0x24]
