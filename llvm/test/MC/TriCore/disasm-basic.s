# RUN: llvm-mc --arch tricore -disassemble < %s | FileCheck %s
# Smoke tests for the TriCore MCDisassembler.
# Each group: encoded bytes followed by a CHECK line.
# Note: '#' is the only comment character recognised by llvm-mc -disassemble.

# ---------------------------------------------------------------------------
# 16-bit instructions
# ---------------------------------------------------------------------------

# ret  (SR format, op1=0x00, op2=0x9)
# Encoding: 0x9000 LE -> 0x00 0x90
0x00 0x90
# CHECK: ret

# mov %d2, 7  (SRC format, op1=0x82, d=2, const4=7)
# Encoding: 0x7282 LE -> 0x82 0x72
0x82 0x72
# CHECK: mov %d2, 7

# add %d2, 5  (SRC format, op1=0xC2, d=2, const4=5)
# Encoding: 0x52C2 LE -> 0xC2 0x52
0xC2 0x52
# CHECK: add %d2, 5

# ---------------------------------------------------------------------------
# 32-bit RR format
# ---------------------------------------------------------------------------

# add %d2, %d3, %d4  (RR op1=0x0B, op2=0x00, s1=D4, s2=D3, d=D2)
# Encoding: 0x2000430B LE -> 0x0b 0x43 0x00 0x20
0x0b 0x43 0x00 0x20
# CHECK: add %d2, %d3, %d4

# sub %d2, %d3, %d4  (RR op1=0x0B, op2=0x80, s1=D4, s2=D3, d=D2)
# Encoding: 0x2080430B LE -> 0x0b 0x43 0x80 0x20
0x0b 0x43 0x80 0x20
# CHECK: sub %d2, %d3, %d4

# ---------------------------------------------------------------------------
# 32-bit BOL format  (ld.w / ld.a use 16-bit offset)
# ---------------------------------------------------------------------------

# ld.w %d2, [%a4] 0  (BOL op1=0x19, d=D2, base=A4, off=0)
# Encoding: 0x00004219 LE -> 0x19 0x42 0x00 0x00
0x19 0x42 0x00 0x00
# CHECK: ld.w %d2, [%a4] 0

# ---------------------------------------------------------------------------
# 32-bit BO format  (stores use 10-bit offset)
# ---------------------------------------------------------------------------

# st.w [%a5] 0, %d4  (BO op1=0x89, op2=0x24, d=D4, base=A5, off=0)
# Encoding: 0x09005489 LE -> 0x89 0x54 0x00 0x09
0x89 0x54 0x00 0x09
# CHECK: st.w [%a5] 0, %d4
