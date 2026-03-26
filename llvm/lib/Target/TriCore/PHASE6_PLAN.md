# TriCore Backend — Phase 6: ELF & Linker Implementation Plan

## Goal

Produce a complete, working toolchain capable of compiling C, C++, and Rust source
files into a TriCore ELF binary that can be flashed to a target device. This
covers the remaining ELF/linker work after Phase 6.1 (already complete).

---

## Status

| Sub-phase | Task                                  | Status        |
|-----------|---------------------------------------|---------------|
| 6.1       | ELF relocations (assembler/MC layer)  | ✅ Complete   |
| 6.2       | LLD linker support                    | ❌ Not started |
| 6.3       | Linker script & memory-map support    | ❌ Not started |
| 6.4       | ELF section flags for memory regions  | ❌ Not started |
| 6.5       | LTO (Link-Time Optimisation)          | ❌ Not started |
| 6.6       | llvm-objdump / llvm-readelf support   | ❌ Not started |

---

## Background: What the Assembler Already Emits (6.1 recap)

The MC layer emits the following relocation types into `.o` files. LLD must be
able to **apply** each of these when producing the final ELF:

| Fixup kind                       | ELF relocation type  | Used for                                      |
|----------------------------------|----------------------|-----------------------------------------------|
| `fixup_tricore_branch16`         | `R_TRICORE_16REL`    | 16-bit SB/SBR conditional branches (JNZ, JZ) |
| `fixup_call`                     | `R_TRICORE_24REL`    | 24-bit `call` / `j` instructions              |
| `fixup_tricore_mov_hi16_pcrel`   | `R_TRICORE_PCHI`     | Upper 16 bits of PC-relative address (MOVH.A) |
| `fixup_tricore_mov_lo16_pcrel`   | `R_TRICORE_PCLO`     | Lower 16 bits of PC-relative address (LEA)   |
| `FK_Data_4` (non-PCrel)          | `R_TRICORE_32ABS`    | `.long symbol` in data sections               |
| `FK_Data_4` (PCrel)              | `R_TRICORE_32REL`    | `.long symbol - .` relative data refs        |
| `FK_Data_2`                      | `R_TRICORE_16ABS`    | `.short symbol`                               |

### Relocation bit-field encoding (needed for LLD `applyRelocation`)

| Relocation        | Instruction format | Bits to patch                                              |
|-------------------|--------------------|------------------------------------------------------------|
| `R_TRICORE_16REL` | SB/SBR (16-bit)    | disp4 [11:8] of 16-bit instruction word; value = (S−P)/2  |
| `R_TRICORE_24REL` | B (32-bit)         | disp24 [31:8]; value = (S−P)/2                            |
| `R_TRICORE_PCHI`  | RLC (32-bit)       | const16 [27:12]; value = ((S−P) >> 16) & 0xFFFF           |
| `R_TRICORE_PCLO`  | BOL (32-bit)       | off16 [27:12]; value = (S−P) & 0xFFFF                     |
| `R_TRICORE_32ABS` | data word          | full 32-bit word; value = S                                |
| `R_TRICORE_32REL` | data word          | full 32-bit word; value = S−P                              |
| `R_TRICORE_16ABS` | data halfword      | full 16-bit halfword; value = S & 0xFFFF                  |

All TriCore instructions are little-endian 16- or 32-bit words.

---

## 6.2 LLD Linker Support

### Goal

Enable `ld.lld --target=tricore-unknown-elf` to link `.o` files produced by
`llc`/`clang` into a flashable ELF. Scope: static linking + PIE
(position-independent executables). No shared libraries / dynamic linker.

### Files to Create

- `lld/ELF/Arch/TriCore.cpp` — relocation application, target class

### Files to Modify

- `lld/ELF/Target.cpp` — register TriCore in `getTarget()` dispatch (add
  `case EM_TRICORE:`)
- `lld/ELF/Target.h` — declare `createTriCoreTargetInfo()`
- `lld/ELF/CMakeLists.txt` — add `Arch/TriCore.cpp` to sources
- `lld/ELF/InputFiles.cpp` — add `EM_TRICORE` to ELF class check if needed

### Implementation Steps

#### Step 1 — Skeleton (`TriCore.cpp`)

Model on `lld/ELF/Arch/MSP430.cpp` (the smallest bare-metal target, ~94 lines).
The minimum viable class:

```cpp
namespace {
class TriCore final : public TargetInfo {
public:
  TriCore();
  RelExpr getRelExpr(RelType type, const Symbol &s,
                     const uint8_t *loc) const override;
  void relocate(uint8_t *loc, const Relocation &rel,
                uint64_t val) const override;
};
} // namespace
```

#### Step 2 — `getRelExpr`: classify relocations as absolute or PC-relative

```
R_TRICORE_32ABS, R_TRICORE_16ABS                → R_ABS
R_TRICORE_32REL, R_TRICORE_16REL, R_TRICORE_24REL,
R_TRICORE_PCHI, R_TRICORE_PCLO                  → R_PC
R_TRICORE_NONE                                  → R_NONE
```

#### Step 3 — `relocate`: apply each relocation by patching instruction bits

For each relocation type, extract `val`, range-check, mask, and write back into
the instruction encoding. Key details per type:

- **`R_TRICORE_24REL`** (CALL/J): `val = (S − P) / 2`; fits in 24 signed bits.
  Encode into bits [31:8] of the 32-bit B-format word.
- **`R_TRICORE_16REL`** (JNZ/JZ): `val = (S − P) / 2`; fits in 4 signed bits
  (±8 bytes). Encode into bits [11:8] of the 16-bit SBR word.
- **`R_TRICORE_PCHI`** (MOVH.A): `val = ((S − P) >> 16) & 0xFFFF`. Encode into
  bits [27:12] of the 32-bit RLC word.
- **`R_TRICORE_PCLO`** (LEA): `val = (S − P) & 0xFFFF`. Encode into bits
  [27:12] of the 32-bit BOL word (sign-extended 16-bit offset).
- **`R_TRICORE_32ABS`**: write `val` as a full 32-bit little-endian word.
- **`R_TRICORE_32REL`**: write `val = S − P` as a full 32-bit little-endian word.
- **`R_TRICORE_16ABS`**: write `val & 0xFFFF` as a 16-bit little-endian halfword.

#### Step 4 — Range error reporting

Use `checkInt` / `checkUInt` (from `lld/ELF/Target.h`) for each fixup so that
out-of-range relocations produce a clear diagnostic rather than silent truncation.

#### Step 5 — PIE support

For PIE, nothing extra is needed for TriCore bare-metal: the compiler emits
`MOVH.A` + `LEA` pairs for absolute addresses using `R_TRICORE_PCHI` /
`R_TRICORE_PCLO`, which are already PC-relative. No GOT/PLT infrastructure is
needed for static PIE without dynamic linking.

### Tests

- `lld/test/ELF/tricore-relocs.s` — assemble a small file and link it; verify
  relocation values are patched correctly by examining the output with
  `llvm-objdump -d` and `llvm-readelf -r`.
- `lld/test/ELF/tricore-branch-range.s` — verify out-of-range branch produces
  a clear error.
- `lld/test/ELF/tricore-call.s` — simple `call` to an external symbol.
- `lld/test/ELF/tricore-pie.s` — link with `-pie` flag; verify output ELF type
  is `ET_DYN` and text is position-independent.

### Effort: Medium (~250–300 lines, comparable to AVR)

---

## 6.3 Linker Script & Memory-Map Support

### Goal

Allow users to give LLD a linker script describing the target device's memory
layout (flash, RAM, etc.) so the linker places sections correctly for flashing.

### What This Means

LLD's linker script parser (`lld/ELF/ScriptParser.cpp`) already supports the
full GNU-ld linker script language. **No new LLD code is needed** for basic
linker script support — it works for any target once 6.2 is complete.

What needs to be documented and tested:

1. **A reference linker script template** for a typical AURIX TC2xx device, e.g.:

```ld
/* tricore-tc27x.ld — typical AURIX TC27x memory layout */
MEMORY {
  PFLASH  (rx)  : ORIGIN = 0x80000000, LENGTH = 2M   /* program flash */
  DFLASH  (r)   : ORIGIN = 0xAF000000, LENGTH = 128K /* data flash    */
  DSPR    (rwx) : ORIGIN = 0xD0000000, LENGTH = 112K /* local DSPR    */
  PSPR    (rwx) : ORIGIN = 0xC0000000, LENGTH = 24K  /* local PSPR    */
  LMU_SRAM (rw) : ORIGIN = 0x90000000, LENGTH = 32K  /* LMU SRAM      */
}

SECTIONS {
  .text   : { *(.text*)   } > PFLASH
  .rodata : { *(.rodata*) } > PFLASH
  .data   : { *(.data*)   } > DSPR AT > PFLASH  /* LMA in flash, VMA in RAM */
  .bss    : { *(.bss*)    } > DSPR
  .stack  : { . = ALIGN(8); . += 4K; } > DSPR
}
```

2. **Test**: link a minimal program using this script and verify section
   addresses in the output ELF with `llvm-readelf -S`.

### Files

- New: `lld/test/ELF/tricore-linkerscript.s` — integration test
- New: `docs/TriCoreLinkerScript.rst` or inline in backend docs — memory map
  templates for common AURIX devices (TC22x, TC27x, TC39x)

### Effort: Small (no code changes to LLD, only tests + docs)

---

## 6.4 ELF Section Flags for Memory Regions

### Goal

Ensure that TriCore-specific code and data sections are emitted with the correct
ELF section flags (`SHF_ALLOC`, `SHF_WRITE`, `SHF_EXECINSTR`, `SHF_MERGE`,
etc.) so a linker script can place them into the correct memory region on the
device (flash vs RAM vs DSPR vs PSPR).

### What ELF Section Flags Mean for Embedded

- `SHF_ALLOC` (`a`) — section is loaded into device memory at runtime
- `SHF_EXECINSTR` (`x`) — section contains executable code → must go into
  flash or PSPR (execute-from-flash or execute-from-RAM)
- `SHF_WRITE` (`w`) — section is writable → must go into RAM (DSPR/LMU)
- `SHF_MERGE` + `SHF_STRINGS` — mergeable string/constant data → can go into
  flash (read-only)

### Current State

The LLVM MC layer emits correct standard flags for standard sections:
- `.text` → `ax` (alloc + exec) — correct, lands in flash
- `.rodata` → `a` (alloc, read-only) — correct, lands in flash
- `.data` → `aw` (alloc + write) — correct, LMA in flash, VMA in RAM
- `.bss` → `aw` (alloc + write, no file data) — correct

### What Needs Work

1. **Custom named sections via `__attribute__((section("name")))`**: When a user
   places a variable or function in a custom section (e.g.
   `__attribute__((section(".dspr.fast")))` or `__attribute__((section(".pspr")))`),
   the Clang/LLVM MC layer must propagate the user-supplied section flags.
   This works today via the `SectionKind` infrastructure — **verify it works
   end-to-end for TriCore** by testing with a C file that uses custom sections.

2. **`.tcA` / `.tcB` sections**: Some TriCore toolchains use vendor-defined
   section names (e.g. `.zbss`, `.zdata` for near-addressed small-data, or
   `.cpu0.text` for multi-core). These are not standard LLVM sections.
   Document how users can control section placement via `-mllvm` flags or
   pragma/attribute annotations in the Clang frontend.

3. **LLD section flag pass-through**: Verify LLD correctly preserves and merges
   input section flags when placing sections. No code changes expected — just
   verification + tests.

### Files

- New: `llvm/test/CodeGen/TriCore/sections.ll` — verify `.text`, `.data`,
  `.rodata`, `.bss` flags; test custom-named sections
- New: `clang/test/CodeGen/tricore-sections.c` — end-to-end C test with
  `__attribute__((section(...)))` producing correct flags
- Possibly: `llvm/lib/Target/TriCore/TriCoreTargetObjectFile.cpp` — if any
  TriCore-specific section handling is needed (currently uses default
  `TargetLoweringObjectFileELF`)

### Effort: Small–Medium

---

## 6.5 LTO (Link-Time Optimisation)

### Goal

Enable LTO so that code compiled across multiple translation units can be
optimised as a whole at link time. For embedded TriCore targets this primarily
reduces code size (dead code elimination, inlining across TUs, constant
propagation).

### How LTO Works in LLVM/LLD

LLD supports two LTO modes, both built on top of existing LLVM IR infrastructure
— no TriCore-specific LTO code is needed once LLD 6.2 is complete:

1. **Full LTO** (`-flto` / `ld.lld --lto=full`): all bitcode `.o` files are
   merged into one LLVM module, optimised, then compiled to native code.

2. **ThinLTO** (`-flto=thin` / `ld.lld --lto=thin`): each module is optimised
   independently with summary-based cross-module information, allowing parallel
   compilation. Preferred for large projects.

### What Needs to Be Done

1. **Verify the LLVM TriCore target is registered for LTO**: the `LLVMInitializeTriCore*`
   functions must be called in the LTO pipeline. Check that `TriCoreTargetMachine`
   is compiled into `libLLVMTriCoreCodeGen.a` and that LLD links against it.

2. **Test full LTO end-to-end**:
   ```sh
   clang --target=tricore-unknown-elf -flto -c foo.c -o foo.bc.o
   clang --target=tricore-unknown-elf -flto -c bar.c -o bar.bc.o
   ld.lld --target=tricore-unknown-elf foo.bc.o bar.bc.o -T tc27x.ld -o app.elf
   ```
   Verify the output ELF is smaller than without LTO (dead functions removed).

3. **Test ThinLTO**:
   ```sh
   clang --target=tricore-unknown-elf -flto=thin -c foo.c -o foo.o
   ld.lld --target=tricore-unknown-elf --lto=thin foo.o bar.o -T tc27x.ld -o app.elf
   ```

4. **`-Os` / `-Oz` interaction**: Verify that LTO combined with `-Oz`
  (optimize for size) produces correct results for TriCore.

### Files

- New: `lld/test/ELF/tricore-lto.ll` — bitcode LTO round-trip test
- New: `lld/test/ELF/tricore-thinlto.ll` — ThinLTO round-trip test

### Effort: Small (no new code — LTO is target-agnostic in LLVM/LLD; effort is
testing and verification only)

---

## 6.6 llvm-objdump / llvm-readelf TriCore Support Verification

### Goal

Verify that the standard LLVM binary analysis tools work correctly with TriCore
ELF files, so developers can inspect, debug, and verify their binaries.

### Tools to Verify

#### `llvm-readelf`
`llvm-readelf` is fully target-agnostic — it only reads ELF header fields, which
are already defined for TriCore (`EM_TRICORE = 44`). **No code changes needed.**

Verification checklist:
- `llvm-readelf -h` — shows `Machine: TriCore` (not `Unknown`)
- `llvm-readelf -S` — shows correct section headers with flags
- `llvm-readelf -r` — shows symbolic relocation type names (e.g.
  `R_TRICORE_24REL`) rather than hex numbers

The relocation type names come from `ELFRelocs/TriCore.def`, which already
exists. Verify they display correctly.

#### `llvm-objdump`
`llvm-objdump -d` uses the TriCore disassembler, which is already implemented.
Verification checklist:
- `llvm-objdump -d app.elf` — disassembles `.text` section correctly
- `llvm-objdump -d --reloc app.o` — shows relocation annotations inline with
  disassembly
- `llvm-objdump -t app.elf` — shows symbol table correctly

#### `llvm-nm`
`llvm-nm` is fully target-agnostic. **No code changes needed.** Verify it can
read TriCore `.o` and `.elf` symbol tables.

#### `llvm-size`
`llvm-size app.elf` — shows `.text`, `.data`, `.bss` sizes; useful for
tracking code size during development. **No code changes needed.**

### Files

- New: `llvm/test/tools/llvm-readelf/TriCore/basic.yaml` — llvm-readelf test
  using a YAML-encoded ELF object
- New: `llvm/test/tools/llvm-objdump/TriCore/disasm.s` — assemble + objdump
  round-trip test verifying inline relocation annotations
- New: `llvm/test/tools/llvm-nm/TriCore/basic.yaml` — nm symbol table test

### Effort: Small (no code; tests only)

---

## Implementation Order

The sub-phases have dependencies as follows:

```
6.2 LLD core  ──► 6.3 Linker scripts (tests only)
              ──► 6.5 LTO verification
6.4 Section flags  (parallel with 6.2 — can start now)
6.6 Tool verification  (parallel with 6.2 — can start now)
```

**Recommended sequence:**

1. **6.6** — Run the tool verification first (no code, quick wins, uncovers any
   gaps in existing `TriCore.def` or disassembler)
2. **6.4** — Write and run section flag tests (uncovers any `TargetObjectFile`
   issues before linking)
3. **6.2** — Implement `lld/ELF/Arch/TriCore.cpp` and wire it in
4. **6.3** — Write linker script tests and MEMORY layout template
5. **6.5** — Verify LTO works end-to-end

---

## Definition of Done

Phase 6 is complete when:

- [ ] `ld.lld` can link a multi-file C/C++ program into a TriCore ELF without
  errors or warnings about unknown relocations
- [ ] The output ELF can be placed at the correct flash/RAM addresses using a
  standard linker script (`MEMORY` + `SECTIONS`)
- [ ] `llvm-objdump -d` disassembles the output ELF correctly
- [ ] `llvm-readelf -h` reports `Machine: TriCore` (not `Unknown`)
- [ ] `llvm-readelf -r` shows symbolic relocation type names
- [ ] LTO (`-flto`) produces a smaller binary than non-LTO (dead code removed)
- [ ] All existing 42/42 TriCore tests still pass
- [ ] New LLD and tool tests added: at minimum the tests listed in 6.2 and 6.6

---

## Reference

- TriCore ELF ABI v2.3 — `docs/Infineon-TC2xx_EABI-UM-v02_09-EN.md`
- TriCore Architecture vol. 1 & 2 — `docs/Infineon-TC2xx_Architecture_vol1-UM-v01_00-EN.md`
- LLD MSP430 reference: `lld/ELF/Arch/MSP430.cpp` (~94 lines, simplest bare-metal target)
- LLD AVR reference: `lld/ELF/Arch/AVR.cpp` (~256 lines, embedded with range checks)
