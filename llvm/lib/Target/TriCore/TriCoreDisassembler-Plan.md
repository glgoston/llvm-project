# TriCore MCDisassembler – Implementation Plan

## 1. Overview

An MCDisassembler converts a stream of raw bytes into an `MCInst` object that
the `InstPrinter` can then render as text.  For TriCore this means:

1. Determine whether the next instruction is 16-bit or 32-bit (done by
   inspecting bits [1:0] of the first byte – see §2.1).
2. Assemble a 16- or 32-bit word in little-endian byte order.
3. Feed the word to the TableGen-generated `decodeInstruction()` dispatch table.
4. Provide hand-written decoder callbacks for every register class and every
   operand kind that needs post-processing (memory addresses, sign-extended
   immediates, branch displacements, …).
5. Register the disassembler with the LLVM target registry.

The TableGen backend (`-gen-disassembler`) already emits the decode table from
the instruction definitions in `TriCore.td`; the only manual work is the items
in steps 1–5.

---

## 2. TriCore Instruction Encoding Primer

### 2.1 16-bit vs 32-bit detection

According to the TriCore v1.6 ISA, bits [1:0] of the opcode byte distinguish
instruction widths:

| bits[1:0] | Width |
|-----------|-------|
| `01`      | 16-bit (compact / "short" encoding) |
| all others | 32-bit |

So `(Bytes[0] & 0x01) == 0` → 32-bit; `(Bytes[0] & 0x01) == 1` → 16-bit.

> **Implementation note:** Read `Bytes[0]` first and branch on bit 0 before
> attempting to assemble the full word.

### 2.2 Instruction format layouts (from `TriCoreInstrFormats.td`)

| Format | Width | Key fields |
|--------|-------|-----------|
| `T16` | 16 | Generic 16-bit container |
| `SRR` | 16 | `[15:12]=s2`, `[11:8]=d`, `[7:0]=op1` |
| `SRC` | 16 | `[15:12]=const4`, `[11:8]=d`, `[7:0]=op1` |
| `SC`  | 16 | `[15:8]=const8`, `[7:0]=op1` |
| `SB`  | 16 | `[15:8]=disp8`, `[7:0]=op1` |
| `SBR` | 16 | `[15:12]=s2`, `[11:8]=disp4`, `[7:0]=op1` |
| `SR`  | 16 | `[15:12]=op2`, `[11:8]=d`, `[7:0]=op1` |
| `RR`  | 32 | `[31:28]=d`, `[27:20]=op2`, `[17:16]=n`, `[15:12]=s2`, `[11:8]=s1`, `[7:0]=op1` |
| `RR2` | 32 | `[31:28]=d`, `[27:16]=op2`, `[15:12]=s2`, `[11:8]=s1`, `[7:0]=op1` |
| `RLC` | 32 | `[31:28]=d`, `[27:12]=const16`, `[11:8]=s1`, `[7:0]=op1` |
| `RC`  | 32 | `[31:28]=d`, `[27:21]=op2`, `[20:12]=const9`, `[11:8]=s1`, `[7:0]=op1` |
| `B`   | 32 | `[7:0]=op1`, `[15:8]=disp24[23:16]`, `[31:16]=disp24[15:0]` |
| `BRR` | 32 | `[31]=op2`, `[30:16]=disp15`, `[15:12]=s2`, `[11:8]=s1`, `[7:0]=op1` |
| `BRC` | 32 | `[31]=op2`, `[30:16]=disp15`, `[15:12]=const4`, `[11:8]=s1`, `[7:0]=op1` |
| `RCPW`| 32 | `[31:28]=d`, `[27:23]=pos`, `[22:21]=op2`, `[20:16]=width`, `[15:12]=const4`, `[11:8]=s1`, `[7:0]=op1` |
| `RRPW`| 32 | same shape as RCPW with `s2` in place of `const4` |
| `BOL` | 32 | Scrambled 20-bit offset + d; see §4.4 below |
| `BO`  | 32 | Scrambled 14-bit offset + op2 + d |

### 2.3 Register classes

| Class | Registers | 4-bit encoding |
|-------|-----------|----------------|
| `DataRegs` | D0–D15 | 0–15 |
| `AddrRegs` | A0–A15 | 0–15 |
| `ExtRegs`  | E0,E2,E4,…E14 | even number / 2 |

Both `DataRegs` and `AddrRegs` encode their index directly in the 4-bit
`s1`/`s2`/`d` fields (determined by context / instruction definition).

`ExtRegs` encode the lower sub-register number (always even); the upper
sub-register is implied.

---

## 3. File Structure to Create

```
llvm/lib/Target/TriCore/
└── Disassembler/
    ├── CMakeLists.txt            ← new
    └── TriCoreDisassembler.cpp   ← new
```

The `TriCoreAsmParser` lives in `AsmParser/`; the disassembler mirrors that
pattern.

---

## 4. Step-by-Step Implementation

### Step 0 – Prerequisites (TableGen)

Verify that `TriCore.td` generates  `TriCoreGenDisassemblerTable.inc` cleanly:

```bash
cmake --build build --target TriCoreCommonTableGen 2>&1 | grep -i error
```

This `.inc` file is already declared in `CMakeLists.txt`:

```cmake
tablegen(LLVM TriCoreGenDisassemblerTable.inc -gen-disassembler)
```

> If the tablegen step fails because instructions lack `EncoderMethod` or have
> unbound fields, those need fixing first – but in practice the existing
> TableGen descriptions are sufficient for decoding.

---

### Step 1 – `Disassembler/CMakeLists.txt`

```cmake
add_llvm_component_library(LLVMTriCoreDisassembler
  TriCoreDisassembler.cpp

  LINK_COMPONENTS
  MCDisassembler
  TriCoreDesc
  TriCoreInfo
  MC
  Support

  ADD_TO_COMPONENT
  TriCore
)
```

Then un-comment the existing line in the top-level `CMakeLists.txt`:

```cmake
# Before:
#add_subdirectory(Disassembler)

# After:
add_subdirectory(Disassembler)
```

---

### Step 2 – Class declaration in `TriCoreDisassembler.cpp`

```cpp
#include "TargetInfo/TriCoreTargetInfo.h"
#include "MCTargetDesc/TriCoreMCTargetDesc.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDecoderOps.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/MathExtras.h"

using namespace llvm;

#define DEBUG_TYPE "tricore-disassembler"
typedef MCDisassembler::DecodeStatus DecodeStatus;

namespace {
class TriCoreDisassembler : public MCDisassembler {
public:
  TriCoreDisassembler(const MCSubtargetInfo &STI, MCContext &Ctx)
      : MCDisassembler(STI, Ctx) {}

  DecodeStatus getInstruction(MCInst &Instr, uint64_t &Size,
                              ArrayRef<uint8_t> Bytes, uint64_t Address,
                              raw_ostream &CStream) const override;
};
} // namespace
```

---

### Step 3 – Byte-reader helpers

```cpp
// Read 2 bytes (little-endian) and assemble a 16-bit word.
static bool readInstruction16(ArrayRef<uint8_t> Bytes,
                               uint64_t &Size, uint16_t &Insn) {
  if (Bytes.size() < 2) { Size = 0; return false; }
  Insn = Bytes[0] | (Bytes[1] << 8);
  return true;
}

// Read 4 bytes (little-endian) and assemble a 32-bit word.
static bool readInstruction32(ArrayRef<uint8_t> Bytes,
                               uint64_t &Size, uint32_t &Insn) {
  if (Bytes.size() < 4) { Size = 0; return false; }
  Insn = Bytes[0] | (Bytes[1] << 8) | (Bytes[2] << 16) | (Bytes[3] << 24);
  return true;
}
```

---

### Step 4 – Register-class decoder functions

These must be declared **before** the `#include "TriCoreGenDisassemblerTables.inc"` 
line because the generated code references them.

#### 4.1 Data registers (D0–D15)

```cpp
static const unsigned DataRegDecoderTable[] = {
  TriCore::D0,  TriCore::D1,  TriCore::D2,  TriCore::D3,
  TriCore::D4,  TriCore::D5,  TriCore::D6,  TriCore::D7,
  TriCore::D8,  TriCore::D9,  TriCore::D10, TriCore::D11,
  TriCore::D12, TriCore::D13, TriCore::D14, TriCore::D15
};

static DecodeStatus DecodeDataRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                                uint64_t Addr,
                                                const MCDisassembler *Dec) {
  if (RegNo > 15) return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(DataRegDecoderTable[RegNo]));
  return MCDisassembler::Success;
}
```

#### 4.2 Address registers (A0–A15)

```cpp
static const unsigned AddrRegDecoderTable[] = {
  TriCore::A0,  TriCore::A1,  TriCore::A2,  TriCore::A3,
  TriCore::A4,  TriCore::A5,  TriCore::A6,  TriCore::A7,
  TriCore::A8,  TriCore::A9,  TriCore::A10, TriCore::A11,
  TriCore::A12, TriCore::A13, TriCore::A14, TriCore::A15
};

static DecodeStatus DecodeAddrRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                                uint64_t Addr,
                                                const MCDisassembler *Dec) {
  if (RegNo > 15) return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(AddrRegDecoderTable[RegNo]));
  return MCDisassembler::Success;
}
```

#### 4.3 Extended (64-bit) registers (E0, E2, …, E14)

The encoding field holds the even sub-register index (0, 2, 4, …, 14).

```cpp
static const unsigned ExtRegDecoderTable[] = {
  TriCore::E0,  TriCore::E2,  TriCore::E4,  TriCore::E6,
  TriCore::E8,  TriCore::E10, TriCore::E12, TriCore::E14
};

static DecodeStatus DecodeExtRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                               uint64_t Addr,
                                               const MCDisassembler *Dec) {
  // RegNo is the 4-bit field value; valid values are 0,2,4,…,14.
  if (RegNo > 14 || (RegNo & 1)) return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(ExtRegDecoderTable[RegNo >> 1]));
  return MCDisassembler::Success;
}
```

> **Check:** Verify how TableGen names the decode function – it is typically
> `Decode<RegisterClassName>RegisterClass`.  Inspect the generated
> `TriCoreGenDisassemblerTables.inc` after the first build to confirm the exact
> symbol names.

---

### Step 5 – Special operand decoders

#### 5.1 BOL scrambled 20-bit memory offset

The `BOL` format scrambles a 20-bit offset across four non-contiguous bit
ranges (from `TriCoreInstrFormats.td`):

```
Inst[11:8]   = memri[3:0]    (4 bits  – off[3:0])
Inst[21:16]  = memri[9:4]    (6 bits  – off[9:4])
Inst[27:22]  = memri[19:14]  (6 bits  – off[19:14])
Inst[31:28]  = memri[13:10]  (4 bits  – off[13:10])
Inst[11:8]   = d             (but this overlaps! – the 'd' register is
                               *not* part of memri; see format carefully)
```

Re-reading the format definition more carefully:

```
Inst{7-0}   = op1
Inst{11-8}  = d              ← destination register
Inst{15-12} = memri{3-0}     ← off[3:0]
Inst{21-16} = memri{9-4}     ← off[9:4]
Inst{27-22} = memri{19-14}   ← off[19:14]
Inst{31-28} = memri{13-10}   ← off[13:10]
```

The assembler encodes a `(base_reg, offset)` pair into `memri` as
`(offset << 4) | base_reg_encoding` (20 bits total: [19:4]=off, [3:0]=base).

> **TODO during implementation:** Trace how `encodeMemSrcValue` constructs
> `memri` in `TriCoreMCCodeEmitter.cpp` and write the exact inverse here.

Skeleton:

```cpp
static DecodeStatus DecodeBOLMemOperand(MCInst &Inst, uint32_t Insn,
                                        uint64_t Addr,
                                        const MCDisassembler *Dec) {
  // Reconstruct the 20-bit memri field from the scrambled encoding.
  // Bits 15:12 → memri[3:0]
  // Bits 21:16 → memri[9:4]
  // Bits 27:22 → memri[19:14]
  // Bits 31:28 → memri[13:10]
  unsigned memri =
      ((Insn >> 12) & 0xF)        |   // [3:0]
      (((Insn >> 16) & 0x3F) << 4)  |  // [9:4]
      (((Insn >> 22) & 0x3F) << 14) |  // [19:14]
      (((Insn >> 28) & 0xF) << 10);    // [13:10]

  // Lower 4 bits of memri = base address register index
  unsigned BaseReg = memri & 0xF;
  // Upper 16 bits = signed offset
  int32_t Offset = SignExtend32<16>(memri >> 4);

  if (BaseReg > 15) return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(AddrRegDecoderTable[BaseReg]));
  Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}
```

#### 5.2 BO 10-bit memory offset

Similar scrambling but with a 14-bit `memri` (10-bit offset + 4-bit base):

```
Inst{15:12} = memri{3:0}   (off[3:0]  / base)
Inst{21:16} = memri{9:4}   (off[9:4])
Inst{31:28} = memri{13:10} (off[13:10] – actually the base reg index)
```

> Trace `encodeMemSrcValue` for the `BO` case to confirm bit layout, then
> write the inverse.

#### 5.3 Branch displacement decoders

**B format (24-bit disp):** Bits reassembled from:
```
Insn[15:8]  = disp24[23:16]
Insn[31:16] = disp24[15:0]
```
Reconstruct and sign-extend to compute the PC-relative target:

```cpp
static DecodeStatus DecodeBranchTarget24(MCInst &Inst, uint32_t Insn,
                                         uint64_t Addr,
                                         const MCDisassembler *Dec) {
  unsigned Disp = ((Insn >> 8) & 0xFF) << 16 | ((Insn >> 16) & 0xFFFF);
  int32_t Offset = SignExtend32<24>(Disp) * 2; // word-addressed → byte
  if (!Dec->tryAddingSymbolicOperand(Inst, Addr + Offset, Addr,
                                     /*IsBranch=*/true, 0, 4, 4))
    Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}
```

**BRR / BRC format (15-bit disp):** Bits [30:16], sign-extended × 2:

```cpp
static DecodeStatus DecodeBranchTarget15(MCInst &Inst, uint32_t Insn,
                                          uint64_t Addr,
                                          const MCDisassembler *Dec) {
  unsigned Disp = (Insn >> 16) & 0x7FFF;
  int32_t Offset = SignExtend32<15>(Disp) * 2;
  if (!Dec->tryAddingSymbolicOperand(Inst, Addr + Offset, Addr,
                                     /*IsBranch=*/true, 0, 4, 4))
    Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}
```

#### 5.4 Signed immediate decoders

For immediates that TableGen does not automatically sign-extend (e.g. `const9`
in `RC` format, `const16` in `RLC`):

```cpp
static DecodeStatus DecodeSImm9Operand(MCInst &Inst, unsigned Val,
                                       uint64_t, const MCDisassembler *) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<9>(Val)));
  return MCDisassembler::Success;
}

static DecodeStatus DecodeSImm16Operand(MCInst &Inst, unsigned Val,
                                        uint64_t, const MCDisassembler *) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<16>(Val)));
  return MCDisassembler::Success;
}
```

> Whether these are needed depends on what TableGen emits automatically.  Build
> once, check which `DecoderMethod` strings appear in the generated `.inc` file,
> and implement the matching functions.

---

### Step 6 – Pull in the generated decode tables

```cpp
// Forward declarations must appear BEFORE this include.
#include "TriCoreGenDisassemblerTables.inc"
```

---

### Step 7 – `getInstruction` implementation

```cpp
DecodeStatus TriCoreDisassembler::getInstruction(MCInst &Instr,
                                                 uint64_t &Size,
                                                 ArrayRef<uint8_t> Bytes,
                                                 uint64_t Address,
                                                 raw_ostream &CS) const {
  // TriCore: bit 0 of the first byte tells us the instruction width.
  //   bit 0 == 1  →  16-bit instruction
  //   bit 0 == 0  →  32-bit instruction
  if (Bytes.empty()) { Size = 0; return Fail; }

  if (Bytes[0] & 0x01) {
    // --- 16-bit path ---
    uint16_t Insn16;
    if (!readInstruction16(Bytes, Size, Insn16))
      return Fail;
    DecodeStatus Result =
        decodeInstruction(DecoderTableTriCore16, Instr, Insn16, Address,
                          this, STI);
    if (Result != Fail) { Size = 2; return Result; }
    return Fail;
  }

  // --- 32-bit path ---
  uint32_t Insn32;
  if (!readInstruction32(Bytes, Size, Insn32))
    return Fail;
  DecodeStatus Result =
      decodeInstruction(DecoderTableTriCore32, Instr, Insn32, Address,
                        this, STI);
  if (Result != Fail) { Size = 4; return Result; }
  return Fail;
}
```

> The decoder table names (`DecoderTableTriCore16`, `DecoderTableTriCore32`)
> are derived from the `DecoderNamespace` property in the TableGen `.td` files.
> Verify the exact names in the generated `.inc` file; adjust if necessary.

---

### Step 8 – Factory + registration

```cpp
static MCDisassembler *createTriCoreDisassembler(const Target &T,
                                                  const MCSubtargetInfo &STI,
                                                  MCContext &Ctx) {
  return new TriCoreDisassembler(STI, Ctx);
}

extern "C" LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeTriCoreDisassembler() {
  TargetRegistry::RegisterMCDisassembler(getTheTriCoreTarget(),
                                         createTriCoreDisassembler);
}
```

---

### Step 9 – Register in `TriCoreMCTargetDesc.cpp`

Add a call from `LLVMInitializeTriCoreTargetMC()` (or leave it to the
auto-initializer mechanism — both patterns are used in LLVM):

```cpp
// In LLVMInitializeTriCoreTargetMC() – or separately via the
// LLVM_EXTERNAL_VISIBILITY init function above (preferred).
// No change strictly required; the -gen-disassembler registration
// is triggered via LLVMInitializeTriCoreDisassembler().
```

The linker group in `CMakeLists.txt` (`ADD_TO_COMPONENT TriCore`) ensures
`LLVMInitializeTriCoreDisassembler` is called when the TriCore target is
initialized.

---

## 5. TableGen Prerequisites

Some instruction definitions may need a `DecoderNamespace` or explicit
`DecoderMethod` annotations to help TableGen distinguish the 16-bit and 32-bit
decode tables.  If the build-time `.inc` file shows only a single `DecoderTable`
(no width suffix), add to the format classes:

```tablegen
// In TriCoreInstrFormats.td

class T16<…> : … {
  let DecoderNamespace = "TriCore16";
}

class T32<…> : … {
  let DecoderNamespace = "TriCore32";
}
```

This generates `DecoderTableTriCore16[]` and `DecoderTableTriCore32[]`
separately, matching the names used in `getInstruction` above.

> Without these annotations TableGen may emit a single `DecoderTableTriCore32[]`
> table that tries to decode both widths – which can work if you always pass the
> correct width, but separate tables are cleaner and avoid false positives.

---

## 6. Build System Changes Summary

| File | Change |
|------|--------|
| `llvm/lib/Target/TriCore/CMakeLists.txt` | Un-comment `add_subdirectory(Disassembler)` |
| `llvm/lib/Target/TriCore/Disassembler/CMakeLists.txt` | **New** – define `LLVMTriCoreDisassembler` library |
| `llvm/lib/Target/TriCore/Disassembler/TriCoreDisassembler.cpp` | **New** – full disassembler implementation |
| `llvm/lib/Target/TriCore/TriCoreInstrFormats.td` | Add `DecoderNamespace` to `T16` / `T32` (if needed) |

---

## 7. Testing

### 7.1 Smoke test (no lit required)

After building, verify basic round-trip disassembly with a known encoding.
Example: the 16-bit `ret` instruction encodes as `0x00 0x00`:

```bash
echo '0x00 0x00' | \
  ./build/bin/llvm-mc --arch tricore -disassemble
# Expected: ret
```

A 32-bit `nop` (`0x00 0x00 0x00 0x00` – opcode byte 0x00, 32-bit):

```bash
printf '\x0d\x00\x00\x00' | \
  ./build/bin/llvm-mc --arch tricore -disassemble
```

### 7.2 Assemble-then-disassemble round trip

```bash
BIN=./build/bin

# Assemble to object file (requires AsmParser fix – see TestPlan §2, Issue 1)
$BIN/llvm-mc --arch tricore -filetype=obj \
    llvm/test/MC/TriCore/asm-add.s -o /tmp/add.o

# Extract raw .text and disassemble
$BIN/llvm-objcopy -O binary --only-section=.text /tmp/add.o /tmp/add.bin
$BIN/llvm-mc --arch tricore -disassemble < /tmp/add.bin
```

### 7.3 Add a lit test for disassembly

Create `llvm/test/MC/TriCore/disasm-basic.s`:

```
# RUN: llvm-mc --arch tricore -disassemble < %s | FileCheck %s

# 16-bit: ret    → 0x00 0x00
0x00 0x00
# CHECK: ret

# 16-bit: mov D15, 0 (SRC)  → 0x82 0xF0
0x82 0xF0
# CHECK: mov D15, 0

# 32-bit: add D2, D3, D4 (RR) → 0x0B 0x43 0x00 0x20
0x0b 0x43 0x00 0x20
# CHECK: add D2, D3, D4
```

---

## 8. Likely Pitfalls & Mitigations

| Pitfall | Mitigation |
|---------|-----------|
| Decoder table name mismatch | After first build, grep the `.inc` for `DecoderTable` to find exact names |
| `DecodeXxx` function name not matching TableGen expectation | Check `DecoderMethod` attribute in `.td`; add explicit `let DecoderMethod = "..."` if needed |
| BOL/BO offset reconstruction wrong | Cross-check with `TriCoreMCCodeEmitter::encodeMemSrcValue` – implement the exact inverse |
| Branch offsets off by ×2 | TriCore encodes word-aligned offsets; multiply or divide by 2 accordingly |
| Extended register encoding (E0 = field value 0, E2 = field value 2) | Guard with `if (RegNo & 1) return Fail` |
| 16-bit instructions decoding as 32-bit garbage | Check `T16` vs `T32` DecoderNamespace separation |
| Unimplemented `addImmOperands` in AsmParser causes round-trip failures | Fix separately per TestPlan Issue 1; disassembler works independently |

---

## 9. Work Estimate (Implementation Sequence)

```
[1] Add Disassembler/CMakeLists.txt                        ~5 min
[2] Write class skeleton + byte readers + register tables  ~30 min
[3] Write getInstruction with 16/32-bit dispatch           ~20 min
[4] First build; read generated .inc; fix name mismatches  ~30 min
[5] Implement BOL/BO memory operand decoders               ~45 min
[6] Implement branch displacement decoders                 ~20 min
[7] Implement signed-immediate decoders (if needed)        ~15 min
[8] Smoke-test (echo bytes | llvm-mc -disassemble)         ~15 min
[9] Write lit tests in test/MC/TriCore/                    ~30 min
[10] Add DecoderNamespace to T16/T32 if step 4 requires it ~10 min
```

Total: approximately 3–4 focused hours for a first working disassembler
covering the most common instruction formats.

---

## 10. Dependencies on Other Open Issues

| This plan assumes | Linked TestPlan issue |
|-------------------|-----------------------|
| TableGen `.td` compiles without errors | Prerequisite for Step 0 |
| `TriCoreGenDisassemblerTables.inc` already has a tablegen target in `CMakeLists.txt` | Already present (`-gen-disassembler` line in top-level `CMakeLists.txt`) |
| AsmParser fix (for round-trip tests) | TestPlan §2, Issue 1 – **not** required to write or test the disassembler itself |
| `Triple::tricore` placement | TestPlan §2, Issue 3 – affects `llvm-objdump` but not `llvm-mc -disassemble` |
