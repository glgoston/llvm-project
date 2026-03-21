# TriCore Native Floating-Point Implementation Plan (TC1.6 / FeatureFP)

## 1. Goal
Implement native single-precision floating-point instruction selection for TriCore CPUs with `FeatureFP` (`tc162`, `tc18`, `tc2x`) and reduce soft-float/libcall usage where native instructions exist.

This plan is focused on the instruction set documented in the TC1.6 architecture manual (Volume 2), notably:
- `ADD.F`, `SUB.F`, `MUL.F`, `DIV.F`, `CMP.F`
- `FTOI`, `FTOIZ`, `FTOU`, `FTOUZ`, `ITOF`, `UTOF`
- Advanced instructions to be included in this Phase 4 program (after arithmetic/conversion/compare baseline): `MADD.F`, `MSUB.F`, `QSEED.F`

## 1.1 Confirmed Decisions
1. First native patchset is arithmetic-only (`ADD.F`, `SUB.F`, `MUL.F`, `DIV.F`).
2. `MADD.F`, `MSUB.F`, `QSEED.F` are in scope now, but only after arithmetic/compare/conversion is stable.
3. IEEE corner-case policy: staged parity.
  - First enable native common cases.
  - Keep precise fallback/libcall behavior for edge semantics until fully validated.
4. Keep both codegen paths permanently unless a future maintenance/perf disadvantage is proven:
  - `tc16` soft-float/libcall path
  - `tc162+` native FP path

## 2. Current Backend Baseline
Already implemented:
- `FeatureFP` subtarget feature and CPU gating in `TriCore.td`.
- `f32` calling-convention ABI mapping via bitcast to `i32` in `TriCoreCallingConv.td`.
- SelectionDAG float ops currently expanded/libcalled in `TriCoreISelLowering.cpp` (`FADD`, `FSUB`, `FMUL`, `FDIV`, compares, int<->float conversions).
- Test coverage for libcall behavior (`tc162` and soft-float `tc16`).

Missing for native FP:
- No TableGen instruction defs for native FPU ops in `TriCoreInstrInfo.td`.
- No FP DAG patterns in `TriCoreInstrInfo.td`/`TriCoreISelDAGToDAG.cpp`.
- No MC encoding/decoding tests for FP instructions.
- No CodeGen tests asserting native FP op emission.

## 3. Design Principles
- Keep ABI stable: floats continue to use D-register calling convention.
- Gate native FP codegen strictly on `FeatureFP`.
- Prefer deterministic lowering:
  - `FeatureFP` CPUs: native ops first, libcall fallback only for unsupported semantics.
  - non-`FeatureFP` CPUs: keep soft-float/libcall path.
- Stage rollout by risk: arithmetic first, then compare, then conversions, then advanced instructions.

## 4. Implementation Phases

### Phase A: Native FP arithmetic opcodes and isel
Scope:
- `fadd`, `fsub`, `fmul`, `fdiv` -> `ADD.F`, `SUB.F`, `MUL.F`, `DIV.F` on `FeatureFP`.

Files:
- `llvm/lib/Target/TriCore/TriCoreInstrInfo.td`
- `llvm/lib/Target/TriCore/TriCoreInstrFormats.td` (if a new format class is needed)
- `llvm/lib/Target/TriCore/TriCoreISelLowering.cpp`
- `llvm/lib/Target/TriCore/TriCoreISelDAGToDAG.cpp` (only if custom selection becomes necessary)

Work items:
1. Add FP instruction defs with `Predicates = [HasFP]`.
2. Add `Pat` mappings for `(fadd f32)`, `(fsub f32)`, `(fmul f32)`, `(fdiv f32)`.
3. Flip lowering actions on `FeatureFP` from `Expand` to `Legal`/`Custom` as required by matching strategy.
4. Keep explicit fallback to libcall where legalization still requires it.

Acceptance:
- `llc -mcpu=tc162` emits native FP arithmetic mnemonics.
- `llc -mcpu=tc16` still emits soft-float libcalls.

### Phase B: Native FP comparisons
Scope:
- `fcmp` lowering via `CMP.F` and predicate materialization.

Files:
- `llvm/lib/Target/TriCore/TriCoreInstrInfo.td`
- `llvm/lib/Target/TriCore/TriCoreISelLowering.cpp`
- `llvm/lib/Target/TriCore/TriCoreISelDAGToDAG.cpp` (likely required for condition-code mapping)

Work items:
1. Define `CMP.F` instruction and result/flag semantics in TableGen.
2. Map LLVM `fcmp` condition codes to TriCore compare outcomes.
3. Preserve IEEE behavior expectations (NaN/unordered handling) per architectural semantics.
4. Retain libcall path for condition variants that cannot yet be represented exactly.

Acceptance:
- Ordered compares (`oeq`, `olt`, `ole`, etc.) emit native sequence on `FeatureFP` where supported.
- No regression on existing libcall-based compare tests for unsupported cases.

### Phase C: Native conversion instructions
Scope:
- `fptosi`, `fptoui`, `sitofp`, `uitofp` via native conversion ops.
- Add explicit round-to-zero support where LLVM op semantics require it (`FTOIZ`, `FTOUZ`).

Files:
- `llvm/lib/Target/TriCore/TriCoreInstrInfo.td`
- `llvm/lib/Target/TriCore/TriCoreISelLowering.cpp`

Work items:
1. Define `FTOI`, `FTOIZ`, `FTOU`, `FTOUZ`, `ITOF`, `UTOF` with `HasFP` predicate.
2. Select conversion opcode by required LLVM rounding/semantic mode.
3. Keep libcall fallback for corner cases not faithfully representable initially.

Acceptance:
- Native conversion ops used on `tc162`+ for standard scalar conversion IR.
- Existing conversion behavior remains correct for non-`FeatureFP` CPUs.

### Phase D: Advanced/native performance ops (in-scope for this Phase 4 program)
Scope:
- `MADD.F`, `MSUB.F`, `QSEED.F`.
- FMA contraction and target combines where legal and profitable.

Files:
- `llvm/lib/Target/TriCore/TriCoreInstrInfo.td`
- `llvm/lib/Target/TriCore/TriCoreISelLowering.cpp`

Work items:
1. Add instruction defs and MC support.
2. Introduce patterns for fused ops from LLVM IR (respecting fast-math flags).
3. Add target combines only after baseline correctness is stable.

Acceptance:
- Native advanced ops emitted for eligible patterns under safe flags.

## 5. MC Layer and Assembler/Disassembler Support
Files:
- `llvm/lib/Target/TriCore/MCTargetDesc/*`
- `llvm/test/MC/TriCore/*`
- `llvm/test/MC/Disassembler/TriCore/*`

Work items:
1. Ensure encoding tables exist for new FP opcodes (assembler + disassembler round-trip).
2. Add negative tests for invalid operands/forms.
3. Ensure integrated assembler path in Clang handles all new mnemonics.

Acceptance:
- `llvm-mc` assemble/disassemble round-trip passes for each FP opcode.
- Disassembler emits canonical instruction text.

## 6. Test Plan
### CodeGen tests
Add/update files under `llvm/test/CodeGen/TriCore/`:
- `float-arithmetic.ll`: switch expected output to native FP on `tc162`+.
- `float-cmp-native.ll`: explicit compare condition coverage.
- `float-convert-native.ll`: conversion instruction coverage.
- keep `float-soft-tc16.ll`: validates soft-float fallback.

### MC tests
- `llvm/test/MC/TriCore/fp-encoding.s`
- `llvm/test/MC/TriCore/fp-invalid.s`
- `llvm/test/MC/Disassembler/TriCore/fp.txt`

### Clang integration smoke tests
- extend `clang/test/CodeGen/tricore-basic.c` with scalar float operations on `-mcpu=tc162`.

## 7. Rollout Strategy
1. Land Phase A first (smallest high-value slice).
2. Land Phase B and C in separate reviewable patches.
3. Land Phase D after A/B/C are stable and test-clean.
4. Keep old libcall tests where appropriate and add split RUN lines by CPU (`tc16` vs `tc162`).

## 8. Risks and Mitigations
- Risk: subtle mismatch in IEEE/NaN/denorm behavior vs current libcall path.
  - Mitigation: start with ordered, common operations; keep fallback for edge semantics.
- Risk: compare result/flag plumbing complexity in DAG and branch lowering.
  - Mitigation: introduce compare tests per condition code before broad enablement.
- Risk: encoding uncertainty for some FP op variants.
  - Mitigation: treat manual opcode tables as source of truth; verify with MC round-trip tests.

## 9. Exit Criteria
Native FP implementation is considered complete for Phase 4 when:
1. `fadd/fsub/fmul/fdiv` use native instructions on `FeatureFP` CPUs.
2. Core `fcmp` and int<->float conversions are native for supported semantics.
3. MC assembler/disassembler support exists for all implemented FP opcodes.
4. Focused TriCore LLVM+Clang suites pass with both `tc162` and `tc16` paths.

## 10. Next Execution Steps
1. Implement Phase A native arithmetic instruction defs and patterns.
2. Add/adjust CodeGen tests to require native arithmetic on `tc162`+ while preserving `tc16` soft-float checks.
3. Validate focused TriCore LLVM+Clang suites before starting Phase B.
