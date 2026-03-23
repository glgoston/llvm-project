# LLVM TriCore Backend — Implementation Plan

## Current Status

The TriCore backend has a solid foundation with passing tests. The following components are implemented:

- **Core backend**: TargetMachine, ISel (SelectionDAG), InstrInfo, RegisterInfo, FrameLowering, SubtargetInfo
- **MC layer**: AsmPrinter, MCInstLower, CodeEmitter, ELF Object Writer, AsmParser, Disassembler
- **Calling convention**: EABI v2.3 compliant (D4–D7, E4/E6, A4–A7 for args; D2/E2/A2 for returns)
- **Instructions**: integer core ISA, native single-precision FP (tc162+), and hardware integer divide (tc18+)
- **Processor variants**: generic, tc16, tc162 (FeatureFP), tc18 (FeatureFP+FeatureDiv), tc2x (FeatureFP+FeatureDiv+FeatureMAC)
- **Tests**: broad TriCore CodeGen/MC coverage including globals, structs, varargs, large-stack, float native paths, and div

### Progress Update (2026-03-23)

Completed since the initial draft:

- **Phase 2.4**: `clang/test/CodeGen/tricore-basic.c` is present and passing in focused validation
- **Phase 3.2**: Added/expanded `globals.ll`, `structs.ll`, `varargs.ll`, `large-stack.ll`, `i8-i16-promotion.ll`, `select.ll`, `shifts.ll`, `mul64.ll`
- **Phase 4.x**: Native FP instruction selection and tests are implemented (`float-arithmetic.ll`, `float-calling-conv.ll`, native FP test set)
- **Phase 5.1**: Hardware `div`/`div.u` for tc18+ implemented with tc162 libcall fallback (`llvm/test/CodeGen/TriCore/div.ll`)
- **Phase 5.2**: Added TC1.6P saturating arithmetic (`ADDS`/`ADDS.U`/`SUBS`/`SUBS.U`), saturating absolute (`ABSS`/`ABSS.H` via `llvm.tricore.abss.i32`/`llvm.tricore.abssh.i32`), and integer multiply-accumulate (`MADD`/`MSUB` via `llvm.tricore.madd.i32`/`llvm.tricore.msub.i32`); non-MAC fallback for intrinsics; tests: `mac-sat.ll`, `mac-encoding.s`, `mac-intrinsics.ll`, `mac-int-encoding.s`, `abs.ll`, `abs-encoding.s`
- **Bug fix**: large stack frame prologue/epilogue lowering now correctly handles >255-byte offsets
- **Current focused validation**: 40/40 passed on the combined Clang+LLVM TriCore test subset

---

## Phase 1 — Bug Fixes & Quick Wins

### 1.1 Fix SUB Data-Register Pattern
- **Goal**: Emit `sub` for data registers instead of falling back to `sub.a` / `mov.d`
- **Files**: `TriCoreInstrInfo.td`, `TriCoreISelLowering.cpp`
- **Tests**: Update `arithmetic.ll` to check for `sub` instead of `sub.a`/`mov.d` sequence
- **Effort**: Small

### 1.2 Fix Loop Back-Edge Branch Lowering
- **Goal**: Properly lower conditional branches on loop back-edges
- **Files**: `TriCoreInstrInfo.cpp` (branch analysis/insertion), `TriCoreISelLowering.cpp`
- **Tests**: Update `control-flow.ll` loop tests, add dedicated loop test cases
- **Effort**: Small–Medium

---

## Phase 2 — Clang Frontend Integration

### 2.1 Triple Registration
- **Goal**: Register `tricore` as a recognized architecture in LLVM's Triple
- **Files**:
  - `llvm/lib/TargetParser/Triple.cpp` — add `tricore` to arch enum and parsing (verify if already done)
  - `llvm/include/llvm/TargetParser/Triple.h` — add enum entry if missing
- **Tests**: `llvm/unittests/TargetParser/TripleTest.cpp`
- **Effort**: Small

### 2.2 Clang Target Definition
- **Goal**: Define TriCore as a Clang target so `__TRICORE__` and type information are available
- **Files to create**:
  - `clang/lib/Basic/Targets/TriCore.h` — target info class (data layout, type sizes, builtins, macros)
  - `clang/lib/Basic/Targets/TriCore.cpp` — implementation
- **Files to modify**:
  - `clang/lib/Basic/Targets.cpp` — register TriCore target in the target factory
  - `clang/lib/Basic/CMakeLists.txt` — add new source file
- **Details**:
  - Data layout: `e-m:e-p:32:32-i64:32-a:0:32-n32`
  - Pointer size: 32-bit
  - Predefined macros: `__TRICORE__`, `__TC161__` / `__TC162__` etc. per CPU variant
  - Type definitions: `int` = 32-bit, `long` = 32-bit, `long long` = 64-bit, `float` = 32-bit IEEE 754
- **Tests**: `clang/test/Preprocessor/tricore-target-features.c`
- **Effort**: Medium

### 2.3 Clang Driver / Toolchain
- **Goal**: Enable `clang --target=tricore-unknown-elf hello.c`
- **Files to create**:
  - `clang/lib/Driver/ToolChains/TriCore.h` — toolchain class
  - `clang/lib/Driver/ToolChains/TriCore.cpp` — toolchain implementation (assembler/linker invocation, include paths)
- **Files to modify**:
  - `clang/lib/Driver/Driver.cpp` — register TriCore toolchain in `Driver::getToolChain()`
  - `clang/lib/Driver/CMakeLists.txt` — add new source file
- **Details**:
  - Bare-metal / ELF toolchain (no OS, similar to AVR/MSP430 bare-metal targets)
  - CPU selection via `-mcpu=tc162`, `-mcpu=tc18`, etc.
  - Default to newlib-style sysroot if provided
- **Tests**: `clang/test/Driver/tricore-toolchain.c`
- **Effort**: Medium

### 2.4 CodeGen Integration Verification
- **Goal**: Verify end-to-end C → TriCore assembly with Clang
- **Tests**: Create `clang/test/CodeGen/tricore-basic.c` with simple functions
- **Effort**: Small

---

## Phase 3 — Expanded Test Coverage

### 3.1 MC-Layer Tests
- **Goal**: Verify instruction encoding/decoding round-trips
- **Files to create**:
  - `llvm/test/MC/TriCore/basic-encoding.s` — assemble → disassemble round-trip
  - `llvm/test/MC/TriCore/relocations.s` — relocation types
  - `llvm/test/MC/TriCore/invalid.s` — negative test cases for assembler diagnostics
- **Effort**: Medium

### 3.2 Additional CodeGen Tests
- **Files to create** (under `llvm/test/CodeGen/TriCore/`):
  - `globals.ll` — global variable access, constant pools
  - `structs.ll` — aggregate passing and returning
  - `varargs.ll` — variadic function support
  - `large-stack.ll` — large stack frames, register spill/reload
  - `i8-i16-promotion.ll` — sub-word type promotion correctness
  - `select.ll` — expanded select/cmov patterns
  - `shifts.ll` — shift edge cases (shift by 0, 32, variable amounts)
  - `mul64.ll` — 64-bit multiplication lowering
- **Effort**: Medium

### 3.3 Disassembler Tests
- **Files to create**:
  - `llvm/test/MC/Disassembler/TriCore/basic.txt` — decode hex → assembly
- **Effort**: Small

---

## Phase 4 — Floating-Point Support (tc162+)

### 4.1 FP Instruction Definitions
- **Goal**: Add single-precision IEEE 754 instructions gated on `FeatureFP`
- **Files**: `TriCoreInstrInfo.td` (add `TriCoreInstrFormats.td` entries if needed)
- **Instructions to add**:
  - Arithmetic: `ADD.F`, `SUB.F`, `MUL.F`, `DIV.F`
  - Comparison: `CMP.F` (or fused eq/lt/ge patterns)
  - Conversion: `FTOI`, `ITOF`, `FTOIZ`, `FTOU`, `UTOF`
  - Move: `MOV` to/from FP (if separate FP register file, otherwise reuse D-regs)
- **Effort**: Medium–Large

### 4.2 FP ISel Lowering
- **Goal**: Lower LLVM `fadd`, `fsub`, `fmul`, `fdiv`, `fcmp`, `fptoui`, `fptosi`, `uitofp`, `sitofp`
- **Files**: `TriCoreISelLowering.cpp`, `TriCoreISelDAGToDAG.cpp`
- **Details**: TriCore uses D-registers for FP values; no separate FP register class needed
- **Effort**: Medium

### 4.3 FP Calling Convention
- **Goal**: Handle `float` arguments and return values per EABI
- **Files**: `TriCoreCallingConv.td`, `TriCoreISelLowering.cpp`
- **Tests**: `llvm/test/CodeGen/TriCore/float-arithmetic.ll`, `float-calling-conv.ll`
- **Effort**: Small–Medium

---

## Phase 5 — Hardware Division & DSP

### 5.1 Hardware Division (tc18+)
- **Goal**: Emit `div` / `div.u` when `FeatureDiv` is available
- **Files**: `TriCoreInstrInfo.td`, `TriCoreISelLowering.cpp`
- **Details**: `sdiv`/`udiv` should use hardware instructions on tc18+; fall back to libcall otherwise
- **Tests**: `llvm/test/CodeGen/TriCore/div.ll`
- **Effort**: Small

### 5.2 TC1.6P MAC & Saturating Arithmetic (tc2x)
- **Goal**: Add multiply-accumulate and saturating arithmetic for tc2x (AURIX TC2xx / TC1.6P cores)
- **Background**: These are *standard* TC1.6P instructions (documented under base Integer Arithmetic
  in the TC1.6P/TC1.6E ISA manual), not optional DSP extensions. The feature flag `FeatureMAC`
  indicates the TC1.6P baseline — available on all tc2x and newer cores.
- **Instructions**:
  - Saturating add/sub: `ADDS`, `ADDS.U`, `SUBS`, `SUBS.U`
  - Absolute (saturating): `ABSS`, `ABSS.H`
  - Multiply-accumulate: `MADD`, `MADDU`, `MSUB`, `MSUBU` (32-bit result in D-reg)
  - Extended MAC: `MADD.U`, `MSUB.U` (64-bit result in E-reg pair)
  - Q-format MAC: `MADD.Q`, `MSUB.Q`
- **Files**: `TriCoreInstrInfo.td`, `TriCoreISelLowering.cpp`
- **Details**:
  - Lower `ISD::SADDSAT`/`ISD::UADDSAT` → `adds`/`adds.u`; `ISD::SSUBSAT`/`ISD::USUBSAT` → `subs`/`subs.u`
  - Expose integer MAC via `llvm.tricore.madd.i32` / `llvm.tricore.msub.i32` (tc2x hardware, non-MAC software fallback)
  - Expose saturating absolute via `llvm.tricore.abss.i32` / `llvm.tricore.abssh.i32` (tc2x hardware, non-MAC software fallback)
  - Lower `ISD::SMUL_LOHI` → `madd` where beneficial; expose MADD.Q via `llvm.tricore.maddq` intrinsic (future)
  - Gate all lowerings on `Subtarget.hasMAC()`, expand otherwise
- **Tests**: `llvm/test/CodeGen/TriCore/mac-sat.ll`, `mac-intrinsics.ll`, `abs.ll`; `llvm/test/MC/TriCore/mac-encoding.s`, `mac-int-encoding.s`, `abs-encoding.s`
- **Effort**: Medium

---

## Phase 6 — ELF & Linker

### 6.1 ELF Relocations
- **Goal**: Ensure all TriCore-specific ELF relocation types are correctly handled
- **Files**:
  - `llvm/include/llvm/BinaryFormat/ELFRelocs/TriCore.def` — relocation type definitions
  - `llvm/lib/Target/TriCore/MCTargetDesc/TriCoreELFObjectWriter.cpp`
  - `llvm/lib/Target/TriCore/MCTargetDesc/TriCoreFixups.h`
- **Reference**: Infineon TriCore EABI document, Section "Relocations"
- **Effort**: Medium

### 6.2 LLD Linker Support (optional)
- **Goal**: Support TriCore ELF linking in LLD
- **Files**: `lld/ELF/Arch/TriCore.cpp`, `lld/ELF/Target.h`
- **Details**: Relocation application, PLT/GOT handling (if needed for non-bare-metal), linker scripts
- **Effort**: Large

---

## Phase 7 — Code Quality & Optimization

### 7.1 Scheduling Model
- **Goal**: Define a pipeline model for instruction scheduling
- **Files**: `TriCoreSchedule.td` (new), referenced from `TriCore.td`
- **Details**: Define functional units, instruction latencies, resource usage
- **Effort**: Medium

### 7.2 Peephole Optimizations
- **Goal**: Add target-specific peephole patterns
- **Examples**:
  - Combine `mov` + `add` into `add` with immediate
  - Use 16-bit instruction forms when operands fit
  - Combine compare + branch into fused branch instructions
- **Files**: `TriCoreInstrInfo.cpp` (`optimizeInstruction`), `TriCoreISelLowering.cpp` (DAG combines)
- **Effort**: Medium

### 7.3 16-bit Instruction Selection
- **Goal**: Prefer 16-bit (compact) encodings where possible to reduce code size
- **Details**: TriCore has 16-bit forms for common operations on restricted register sets
- **Files**: `TriCoreInstrInfo.td`, `TriCoreInstrInfo.cpp` (post-RA optimization pass)
- **Effort**: Medium–Large

---

## Phase 8 — Debug & Diagnostics

### 8.1 DWARF Debug Info
- **Goal**: Verify correct DWARF emission
- **Checklist**:
  - [ ] Register numbering matches DWARF spec for TriCore
  - [ ] CFI directives emitted correctly for prologue/epilogue
  - [ ] Location expressions work for variables in registers and on stack
  - [ ] `llvm-dwarfdump` can parse the output
- **Files**: `TriCoreRegisterInfo.td` (DWARF numbers), `TriCoreFrameLowering.cpp` (CFI)
- **Tests**: `llvm/test/DebugInfo/TriCore/`
- **Effort**: Medium

### 8.2 Inline Assembly
- **Goal**: Support `asm("...")` with TriCore register constraints
- **Files**: `TriCoreTargetMachine.cpp` (constraint letters), `TriCoreISelLowering.cpp`
- **Details**: Define constraint letters for D-regs (`d`), A-regs (`a`), extended regs (`e`)
- **Tests**: `clang/test/CodeGen/tricore-inline-asm.c`
- **Effort**: Small–Medium

---

## Phase 9 — GlobalISel (Long-Term)

### 9.1 GlobalISel Implementation
- **Goal**: Implement the modern GlobalISel instruction selection pipeline
- **Files to create**:
  - `TriCoreCallLowering.cpp/.h`
  - `TriCoreLegalizerInfo.cpp/.h`
  - `TriCoreRegisterBankInfo.cpp/.h`
  - `TriCoreInstructionSelector.cpp`
- **Details**: Tablegen GlobalISel targets are already configured in CMakeLists.txt
- **Effort**: Large

---

## Phase 10 — Upstream Preparation

### 10.1 Code Style & Compliance
- [ ] Run `clang-format` on all backend files
- [ ] Ensure all files have LLVM license headers
- [ ] Follow LLVM naming conventions
- [ ] Remove any leftover TODOs or debug code

### 10.2 Documentation
- [ ] Write `llvm/docs/TriCore.rst` — backend overview, supported features, known limitations
- [ ] Add TriCore to `llvm/docs/CompilerWriterInfo.rst`
- [ ] Document any deviations from TriCore EABI

### 10.3 Review Preparation
- [ ] Create an RFC on LLVM Discourse (llvm.discourse.group)
- [ ] Split into reviewable patch series (Triple registration → backend core → Clang integration)
- [ ] Ensure all tests pass in CI

---

## Suggested Priority Order

| Priority | Phase | Description | Blocking? |
|----------|-------|-------------|-----------|
| **P0** | 1.1, 1.2 | Bug fixes (SUB pattern, back-edge branches) | No |
| **P0** | 2.1–2.4 | Clang integration (Triple, Target, Driver) | Yes — enables C compilation |
| **P1** | 3.1–3.3 | Expanded tests | No |
| **P1** | 4.1–4.3 | Floating-point support | Yes — needed for real-world code |
| **P2** | 5.1 | Hardware division | No |
| **P2** | 6.1 | ELF relocations | Partially — needed for linking |
| **P2** | 8.1–8.2 | Debug info & inline asm | No |
| **P3** | 5.2 | DSP extensions | No |
| **P3** | 7.1–7.3 | Optimizations & scheduling | No |
| **P4** | 6.2 | LLD support | No |
| **P4** | 9.1 | GlobalISel | No |
| **P4** | 10.1–10.3 | Upstream preparation | No |
