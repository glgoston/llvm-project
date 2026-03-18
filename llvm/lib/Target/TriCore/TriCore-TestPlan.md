# TriCore Backend Test Plan

## 1. Current Build Status

| Tool | Status | Notes |
|------|--------|-------|
| `llvm-mc` | **Working** | 515 MB, TriCore registered |
| `llc` | **Not linked** | 0-byte file; disk full (99 %) during link |
| `opt` | **Not linked** | 0-byte file; same cause |
| `clang` | Not built | Not in CMake target list |
| `llvm-objdump` | Built | Can inspect ELF output |

### Disk space
The build partition has ~9 GB free out of 662 GB (99 % used).  
Linking `llc` in Release mode requires roughly 300–600 MB of temporary space.  
**Action required before CodeGen tests can run:** free disk space or use
`-DLLVM_USE_LINKER=lld` together with `-DLLVM_LINK_LLVM_DYLIB=ON` to reduce peak
link memory / write size.

---

## 2. Known Issues / Blockers

### Issue 1 – AsmParser operand parsing is unimplemented
**File:** `llvm/lib/Target/TriCore/AsmParser/TriCoreAsmParser.cpp`  
`ParseInstruction` always returns an error the moment it sees any token after the
mnemonic:

```cpp
// The loop body immediately bails out:
Parser.eatToEndOfStatement();
return Error(Loc, "unexpected token parsing operands");
```

**Impact:** Every instruction with operands (i.e., virtually every TriCore
instruction) fails to assemble.  All MC-assembly tests will `FAIL` until this is
fixed.

**Fix sketch:**
```cpp
while (Parser.getTok().isNot(AsmToken::EndOfStatement)) {
  if (!First) eatComma();
  else        First = false;

  SMLoc RegStart, RegEnd;
  MCRegister Reg;
  if (tryParseRegister(Reg, RegStart, RegEnd) == MatchOperand_Success) {
    auto Op = std::make_unique<TriCoreOperand>(KindTy::Register, RegStart, RegEnd);
    Op->Reg.RegNum = Reg;
    Operands.push_back(std::move(Op));
    continue;
  }
  // try immediate …
  const MCExpr *IdVal;
  SMLoc ExprLoc = getLexer().getLoc();
  if (!getParser().parseExpression(IdVal)) {
    auto Op = std::make_unique<TriCoreOperand>(KindTy::Immediate, ExprLoc, getLexer().getLoc());
    Op->Imm.Val = IdVal;
    Operands.push_back(std::move(Op));
    continue;
  }
  return Error(getLexer().getLoc(), "unexpected token parsing operands");
}
```
Also, `addImmOperands` is a stub; it must call `addExpr(Inst, getImm())`.

### Issue 2 – No MCDisassembler
No `TriCoreDisassembler.cpp` exists in `MCTargetDesc/`.  
`llvm-mc -disassemble` and `llvm-objdump -d` cannot decode TriCore binary.  
De-assembling tests (category 2b) require this file to be written.

### Issue 3 – `Triple::tricore` is after `LastArchType = ve`
The `tricore` enumerator was appended *after* `LastArchType` in
`llvm/include/llvm/TargetParser/Triple.h`.  While the target still registers
correctly via `--arch tricore`, some LLVM internal checks that iterate up to
`LastArchType` may silently skip it.  
**Action:** move the `tricore` line before `LastArchType = ve` (or update
`LastArchType`).

---

## 3. Test Infrastructure

### 3.1 Directory layout
```
llvm/test/
├── MC/TriCore/
│   ├── lit.local.cfg        ← selects tricore arch, sets tool path
│   ├── asm-add.s            ← arithmetic instruction encoding
│   ├── asm-mov.s            ← MOV / MOVH instruction encoding
│   ├── asm-branch.s         ← branch / call encoding
│   └── asm-mem.s            ← load / store encoding
└── CodeGen/TriCore/
    ├── lit.local.cfg        ← uses llc -march=tricore
    ├── arithmetic.ll        ← i32 / i64 arithmetic
    ├── calling-conv.ll      ← argument passing, return values
    ├── control-flow.ll      ← if / while / switch
    └── memory.ll            ← load / store / alloca
```

### 3.2 Running the tests
```bash
# Run all TriCore tests (requires llvm-lit on PATH)
llvm-lit llvm/test/MC/TriCore/
llvm-lit llvm/test/CodeGen/TriCore/

# Or via cmake
cmake --build build --target check-llvm-codegen-tricore  # once lit targets exist
```

### 3.3 Single file quick-check (no lit required)
```bash
LLVM=build/bin

# MC assembly (needs AsmParser fix first)
$LLVM/llvm-mc --arch tricore --show-encoding llvm/test/MC/TriCore/asm-add.s

# CodeGen (needs llc)
$LLVM/llc -march=tricore -o /tmp/out.s llvm/test/CodeGen/TriCore/arithmetic.ll
$LLVM/FileCheck llvm/test/CodeGen/TriCore/arithmetic.ll < /tmp/out.s

# Object dump
$LLVM/llvm-objdump -d /tmp/out.o
```

---

## 4. Test Categories

### 4.1 Target Registration (works TODAY)

**Tool:** `llvm-mc --version`  
**Goal:** Confirm the TriCore target is registered in all build tools.

| Test | Command | Expected |
|------|---------|----------|
| llvm-mc registration | `llvm-mc --version` | `tricore - TriCore` in output |
| llc registration | `llc --version` | `tricore` in output |

---

### 4.2 MC Assembly Encoding (requires AsmParser fix)

**Tool:** `llvm-mc --arch tricore --show-encoding`  
**Reference:** TriCore v1.6 Architecture Manual, instruction encoding tables.

#### 4.2.1 Arithmetic Instructions

| Mnemonic | Format | Expected encoding (LE bytes) | Notes |
|----------|--------|------------------------------|-------|
| `add D2, D3, D4` | RR | `0B 43 00 20` | D2 = D3 + D4 |
| `add D2, 5` | SRC | `C2 52` | D2 += 5 (signed 4-bit imm) |
| `add D2, D3, 42` | RC | `8B 32 15 20` | D2 = D3 + 42 (9-bit signed imm) |
| `addi D2, D3, 0x1234` | RLC | `1B 30 23 21` | D2 = D3 + 0x1234 (16-bit signed)|
| `sub D2, D3, D4` | RR | `0B 43 80 20` | D2 = D3 - D4 |
| `mul D2, D3, D4` | RR2 | `73 43 A0 20` | D2 = D3 * D4 |

#### 4.2.2 Logical Instructions

| Mnemonic | Format | Expected encoding | Notes |
|----------|--------|-------------------|-------|
| `and D2, D3, D4` | RR | — | Bitwise AND |
| `or D2, D3, D4` | RR | — | Bitwise OR |
| `xor D2, D3, D4` | SRR | — | Bitwise XOR |
| `not D2, D3` | SR | — | Bitwise NOT |

#### 4.2.3 Move Instructions

| Mnemonic | Format | Expected encoding | Notes |
|----------|--------|-------------------|-------|
| `mov D2, 7` | SRC | `82 72` | 4-bit immediate |
| `mov D2, 0x1234` | RLC | `3B 00 34 21` (approx) | 16-bit signed |
| `mov.u D2, 0x5678` | RLC | `BB 00 78 25` (approx) | 16-bit unsigned |
| `movh D2, 0xABCD` | RLC | `7B 00 CD 2A` (approx) | load into upper half |
| `mov.a A4, D5` | RR | — | data reg → addr reg |
| `mov.d D2, A3` | RR | — | addr reg → data reg |

#### 4.2.4 Shift Instructions

| Mnemonic | Format | Expected encoding | Notes |
|----------|--------|-------------------|-------|
| `sh D2, D3, D4` | RR | `0F 43 00 20` | logical shift |
| `sh D2, D3, 3` | RC | `8F 30 03 20` | logical shift by const |
| `sha D2, D3, D4` | RR | `0F 43 01 20` | arithmetic shift |
| `sha D2, D3, -1` | RC | `8F 30 81 20` | arithmetic shift by -1 |

#### 4.2.5 Load / Store Instructions

| Mnemonic | Format | Expected encoding | Notes |
|----------|--------|-------------------|-------|
| `ld.w D2, [A4]0` | BOL | — | 32-bit load, base+offset |
| `ld.b D2, [A4]4` | BO | — | byte load |
| `ld.h D2, [A4]2` | BO | — | half-word load |
| `st.w [A4]0, D5` | BO | — | 32-bit store |
| `st.b [A4]4, D5` | BO | — | byte store |

#### 4.2.6 Branch / Call Instructions

| Mnemonic | Format | Expected encoding | Notes |
|----------|--------|-------------------|-------|
| `j label` | B | — | unconditional jump |
| `jz D4, label` | BRN | — | jump if zero |
| `jnz D4, label` | BRN | — | jump if not zero |
| `call func` | B | — | direct call |
| `calli A4` | RR | — | indirect call |
| `ret` | T16 | `00 00` | return |

---

### 4.3 MC Disassembly (requires MCDisassembler implementation)

**Tool:** `llvm-mc --arch tricore -disassemble`

Round-trip test: assemble → objcopy raw section bytes → disassemble, compare with
original assembly text.

---

### 4.4 CodeGen: IR → Assembly (requires `llc`)

**Tool:** `llc -march=tricore`

#### 4.4.1 Arithmetic and Registers

```llvm
; arithmetic.ll
define i32 @add_i32(i32 %a, i32 %b) {
  %r = add i32 %a, %b
  ret i32 %r
}
; CHECK: add %d2, %d4, %d5
; CHECK: ret

define i32 @add_imm(i32 %a) {
  %r = add i32 %a, 42
  ret i32 %r
}
; CHECK: add %d2, %d4, 42     ; or addi / add.a depending on const size

define i32 @sub_i32(i32 %a, i32 %b) {
  %r = sub i32 %a, %b
  ret i32 %r
}
; CHECK: sub %d2, %d4, %d5
```

#### 4.4.2 Calling Convention (TriCore EABI v2.3)

| Parameter type | ABI register(s) |
|---------------|-----------------|
| First i32 | D4 |
| Second i32 | D5 |
| Third i32 | D6 |
| Fourth i32 | D7 |
| Pointer arg  | A4, A5, A6, A7  |
| i32 return | D2 |
| Pointer return | A2 |
| i64 return | E2 (D2:D3) |
| Callee-saved | D8–D15, A10–A15 |

```llvm
; calling-conv.ll  – verify argument register allocation
define i32 @four_args(i32 %a, i32 %b, i32 %c, i32 %d) {
  %r = add i32 %a, %d
  ret i32 %r
}
; CHECK: add %d2, %d4, %d7   ; %a → D4, %d → D7
```

#### 4.4.3 Control Flow

```llvm
; control-flow.ll
define i32 @max(i32 %a, i32 %b) {
  %cmp = icmp sgt i32 %a, %b
  %r = select i1 %cmp, i32 %a, i32 %b
  ret i32 %r
}
; CHECK: {{jlt|jge}}
; CHECK: ret
```

#### 4.4.4 Memory Access

```llvm
; memory.ll
define i32 @load32(ptr %p) {
  %v = load i32, ptr %p
  ret i32 %v
}
; CHECK: ld.w %d2, [%a4]
```

#### 4.4.5 Stack / Local Variables

```llvm
define i32 @local_var() {
  %x = alloca i32
  store i32 7, ptr %x
  %v = load i32, ptr %x
  ret i32 %v
}
; CHECK: sub.a %a10, {{[0-9]+}}   ; frame allocation
; CHECK: st.w
; CHECK: ld.w
```

---

### 4.5 Object File Validation (requires working assembler OR llc + llvm-mc)

**Tool:** `llvm-mc -filetype=obj` or `llc -filetype=obj`

Checks to perform with `llvm-readelf` / `llvm-objdump`:

| Check | Command | Expected |
|-------|---------|----------|
| ELF class | `llvm-readelf -h obj.o | grep Class` | `ELF32` |
| Endianness | `llvm-readelf -h obj.o | grep Data` | `2's complement, little endian` |
| Machine type | `llvm-readelf -h obj.o | grep Machine` | `0xE2 (EM_TRICORE)` |
| Section `.text` | `llvm-readelf -S obj.o | grep .text` | present, type PROGBITS |
| Relocation records | `llvm-readelf -r obj.o` | `R_TRICORE_*` for extern refs |

---

## 5. Recommended Fix Priority

```
Priority 1 (unblocks most tests):
  a. Fix ParseInstruction in TriCoreAsmParser.cpp
  b. Implement addImmOperands to actually add the immediate operand
  c. Free disk space / enable LLD to link llc

Priority 2 (disassembly support):
  a. Implement TriCoreDisassembler.cpp
  b. Register it in TriCoreMCTargetDesc.cpp

Priority 3 (full codegen coverage):
  a. Verify all pseudo-instructions are lowered (ADDi64, SUBi64, etc.)
  b. Frame lowering correctness (prologue/epilogue, CSR save/restore)
  c. Inline asm support

Priority 4 (Triple hygiene):
  a. Place `tricore` before `LastArchType = ve` in Triple.h
  b. Add TriCore to `llvm/lib/TargetParser/Triple.cpp` arch name table
```

---

## 6. Test Files Created

The following files have been created alongside this plan:

| File | Purpose | Status |
|------|---------|--------|
| `llvm/test/MC/TriCore/lit.local.cfg` | lit config for MC tests | Ready |
| `llvm/test/MC/TriCore/asm-add.s` | Arithmetic instruction encoding | Needs AsmParser fix |
| `llvm/test/MC/TriCore/asm-mov.s` | Move instruction encoding | Needs AsmParser fix |
| `llvm/test/MC/TriCore/asm-branch.s` | Branch / call encoding | Needs AsmParser fix |
| `llvm/test/CodeGen/TriCore/lit.local.cfg` | lit config for CodeGen tests | Ready |
| `llvm/test/CodeGen/TriCore/arithmetic.ll` | i32/i64 arithmetic | Needs llc |
| `llvm/test/CodeGen/TriCore/calling-conv.ll` | Calling convention | Needs llc |
| `llvm/test/CodeGen/TriCore/control-flow.ll` | if / loop / switch | Needs llc |
| `llvm/test/CodeGen/TriCore/memory.ll` | Load / store / alloca | Needs llc |
