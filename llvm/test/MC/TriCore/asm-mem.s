; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore load/store instruction encoding tests.
;
; Memory instruction formats used by the backend:
;   BO  format (32-bit): base+offset (10-bit signed offset)
;   BOL format (32-bit): base+offset-long (16-bit signed offset)
;
; Addressing syntax: [An] offset   (bracket-enclosed base register, then offset)

; ─── LD.W (BOL format, op1=0x19) ─────────────────────────────────────────────
        ld.w D2, [A4]0
; CHECK: ld.w %d2, [%a4] 0
; CHECK: encoding: [0x19,0x42,0x00,0x00]

        ld.w D2, [A4]4
; CHECK: ld.w %d2, [%a4] 4
; CHECK: encoding: [0x19,0x42,0x04,0x00]

; ─── LD.B (BO format) ────────────────────────────────────────────────────────
        ld.b D2, [A4]0
; CHECK: ld.b %d2, [%a4] 0
; CHECK: encoding: [0x09,0x42,0x00,0x08]

; ─── LD.BU (BO format) ───────────────────────────────────────────────────────
        ld.bu D2, [A4]0
; CHECK: ld.bu %d2, [%a4] 0
; CHECK: encoding: [0x09,0x42,0x40,0x08]

; ─── LD.H (BO format) ────────────────────────────────────────────────────────
        ld.h D2, [A4]0
; CHECK: ld.h %d2, [%a4] 0
; CHECK: encoding: [0x09,0x42,0x80,0x08]

; ─── LD.HU (BO format) ───────────────────────────────────────────────────────
        ld.hu D2, [A4]0
; CHECK: ld.hu %d2, [%a4] 0
; CHECK: encoding: [0x09,0x42,0xc0,0x08]

; ─── LD.A (BOL format, op1=0x99) ─────────────────────────────────────────────
        ld.a A4, [A5]8
; CHECK: ld.a %a4, [%a5] 8
; CHECK: encoding: [0x99,0x54,0x08,0x00]

; ─── ST.W (BO format) ────────────────────────────────────────────────────────
        st.w [A4]0, D5
; CHECK: st.w [%a4] 0, %d5
; CHECK: encoding: [0x89,0x45,0x00,0x09]

        st.w [A4]8, D5
; CHECK: st.w [%a4] 8, %d5
; CHECK: encoding: [0x89,0x45,0x08,0x09]

; ─── ST.B (BO format) ────────────────────────────────────────────────────────
        st.b [A4]0, D5
; CHECK: st.b [%a4] 0, %d5
; CHECK: encoding: [0x89,0x45,0x00,0x08]

; ─── ST.H (BO format) ────────────────────────────────────────────────────────
        st.h [A4]0, D5
; CHECK: st.h [%a4] 0, %d5
; CHECK: encoding: [0x89,0x45,0x80,0x08]

; ─── ST.A (BO format) ────────────────────────────────────────────────────────
        st.a [A4]0, A5
; CHECK: st.a [%a4] 0, %a5
; CHECK: encoding: [0x89,0x45,0x80,0x09]

; ─── Negative offset ─────────────────────────────────────────────────────────
        ld.w D2, [A4]-4
; CHECK: ld.w %d2, [%a4] -4
; CHECK: encoding: [0x19,0x42,0xfc,0xff]

; ─── A10 base register ───────────────────────────────────────────────────────
        ld.w D2, [A10]0
; CHECK: ld.w %d2, [%a10] 0
; CHECK: encoding: [0x19,0xa2,0x00,0x00]
