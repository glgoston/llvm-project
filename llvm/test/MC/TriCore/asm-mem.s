; RUN: llvm-mc --arch tricore --show-encoding %s | FileCheck %s
;
; TriCore load/store instruction encoding tests.
;
; NOTE: Requires AsmParser operand parsing to be implemented first.
;
; Memory instruction formats used by the backend:
;   BO  format (32-bit): base+offset (offset fits 10-bit signed)
;   BOL format (32-bit): base+offset-long (16-bit signed offset)
;
; Addressing syntax: [An]off  or  [An+r]
;
; Load opcodes (BO base opcode 0x09 / BOL base 0x19/0x99):
;   LD.B   – signed byte load
;   LD.BU  – unsigned byte load
;   LD.H   – signed half-word load
;   LD.HU  – unsigned half-word load
;   LD.W   – word load
;   LD.D   – double-word load (into extended register)
;   LD.A   – load address (into address register)
;
; Store opcodes (BO base opcode 0x89):
;   ST.B   – store byte
;   ST.H   – store half-word
;   ST.W   – store word
;   ST.D   – store double-word
;   ST.A   – store address register

; ─── LD.W (BOL format, op1=0x19) ─────────────────────────────────────────────
; LD.W D2, [A4]0  – load 32-bit word from address A4+0 into D2
        ld.w D2, [A4]0
; CHECK: ld.w D2, [A4]0

; LD.W with non-zero offset
        ld.w D2, [A4]4
; CHECK: ld.w D2, [A4]4

; ─── LD.B (BO format, op2=0x20) ──────────────────────────────────────────────
        ld.b D2, [A4]0
; CHECK: ld.b D2, [A4]0

; ─── LD.BU (BO format, op2=0x21) ─────────────────────────────────────────────
        ld.bu D2, [A4]0
; CHECK: ld.bu D2, [A4]0

; ─── LD.H (BO format, op2=0x22) ──────────────────────────────────────────────
        ld.h D2, [A4]0
; CHECK: ld.h D2, [A4]0

; ─── LD.HU (BO format, op2=0x23) ─────────────────────────────────────────────
        ld.hu D2, [A4]0
; CHECK: ld.hu D2, [A4]0

; ─── LD.D (BO format, op2=0x25) – 64-bit load into extended register pair ────
        ld.d E2, [A4]0
; CHECK: ld.d E2, [A4]0

; ─── LD.A (BOL format, op1=0x99) ─────────────────────────────────────────────
; Load address register
        ld.a A4, [A5]8
; CHECK: ld.a A4, [A5]8

; ─── ST.W (BO format, base op1=0x89, op2=0x24) ───────────────────────────────
; ST.W [A4]0, D5  – store D5 to address A4+0
        st.w [A4]0, D5
; CHECK: st.w [A4]0, D5

        st.w [A4]8, D5
; CHECK: st.w [A4]8, D5

; ─── ST.B (BO format, op2=0x20) ──────────────────────────────────────────────
        st.b [A4]0, D5
; CHECK: st.b [A4]0, D5

; ─── ST.H (BO format, op2=0x22) ──────────────────────────────────────────────
        st.h [A4]0, D5
; CHECK: st.h [A4]0, D5

; ─── ST.D (BO format, op2=0x25) ──────────────────────────────────────────────
        st.d [A4]0, E4
; CHECK: st.d [A4]0, E4

; ─── ST.A (BO format, op2=0x26) ──────────────────────────────────────────────
        st.a [A4]0, A5
; CHECK: st.a [A4]0, A5

; ─── Negative / large offsets ────────────────────────────────────────────────
; BOL allows a 16-bit signed offset
        ld.w D2, [A4]-4
; CHECK: ld.w D2, [A4]-4

        ld.w D2, [A10]0
; CHECK: ld.w D2, [A10]0
