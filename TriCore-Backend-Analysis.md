# TriCore LLVM Backend — In-Depth Analysis

> **Scope:** All source files under `llvm/lib/Target/TriCore/`
> **LLVM version:** 16.0.x (release/16.x branch)
> **Date:** 2026-03-18

---

## Table of Contents

1. [Overview](#overview)
2. [Critical Bugs](#critical-bugs)
3. [Serious / High-Priority Issues](#serious--high-priority-issues)
4. [Medium-Priority Issues](#medium-priority-issues)
5. [Missing Features](#missing-features)
6. [Code Quality / Style Issues](#code-quality--style-issues)
7. [Summary Table](#summary-table)

---

## Overview

The TriCore backend is an out-of-tree target for the Infineon/HighTec TriCore 32-bit
embedded processor family. The implementation covers the basics (register classes,
a small instruction set, ELF emission, a custom calling-convention hook), but
the backend is clearly in an early/experimental state. Large subsystems are
commented out, incorrect, or missing entirely. Many debug `outs()` calls are
present throughout production code paths.

The following analysis is strictly a code review; no changes are made. Issues are
grouped by severity.

---

## Critical Bugs

### 1. `SUBXrr` encoding collision with `ADDXrr`

**File:** `TriCoreInstrInfo.td`, lines 140–143 vs 165–169

`ADDXrr` is defined as `RR<0x0B, 0x04>` and `SUBXrr` is also defined as
`RR<0x0B, 0x04>`. Both have identical primary and secondary opcodes. TableGen
will silently emit ambiguous matcher tables, and the back-end will produce
incorrect code whenever one or the other is selected.

```
def ADDXrr : RR<0x0B, 0x04, ...>  // ADDX
def SUBXrr : RR<0x0B, 0x04, ...>  // SUBX — IDENTICAL ENCODING
```

### 2. `BRR` instruction format: s2 field never encoded

**File:** `TriCoreInstrFormats.td`, lines 228–233

In the `BRR` class, both `Inst{11-8}` and `Inst{15-12}` are assigned to `s1`.
The `s2` field is declared but never placed in the instruction word.

```tablegen
let Inst{11-8}  = s1;   // correct
let Inst{15-12} = s1;   // BUG: should be s2
```

Any conditional branch using `BRR` format will have a zeroed s2 field in the
encoding, and the disassembler will read it back as 0 regardless of the actual
operand.

### 3. `zext` and `anyext` lowering is semantically identical to `sext`

**File:** `TriCoreInstrInfo.td`, lines 949–961

The patterns for `zext` (and `anyext`) of a 32-bit data register into a 64-bit
extended register use `SHArc ... (i32 -31)`, which is an arithmetic right shift
by 31 — this replicates the sign bit into the upper word. That is **sign
extension**, not zero extension. A zero extension must clear the upper word (e.g.
by writing 0 into `subreg_odd`).

```tablegen
// zext
def : Pat<(zext DataRegs:$src),
    (INSERT_SUBREG (i64 (IMPLICIT_DEF)),
        (SHArc ( EXTRACT_SUBREG (INSERT_SUBREG (i64 (IMPLICIT_DEF)) ,
            (i32 DataRegs:$src), subreg_even), subreg_even)
            , (i32 -31)), subreg_odd)>;  // BUG: this is sext, not zext
```

Unsigned 32→64 bit promotion will give wrong results for any value with bit 31 set.

### 4. `sext_inreg` for i8 and i16 lowered to a plain register copy

**File:** `TriCoreInstrInfo.td`, lines 926–931

```tablegen
def : Pat<(sext_inreg DataRegs:$src, i16), (MOVrr (i32 DataRegs:$src))>;
def : Pat<(sext_inreg DataRegs:$src, i8),  (MOVrr (i32 DataRegs:$src))>;
```

`MOVrr` is a register-to-register move; it does **no** sign-extension. On
TriCore, sign-extension from 8/16 bits should use the `EXTR` instruction
(extracting bits 0..N-1 with sign-extension) or an arithmetic shift pair.
Any narrower-than-32-bit computation involving signed promotion through
`sext_inreg` will silently produce wrong values.

### 5. `truncstorei8` of an extended register stored as full 32-bit word

**File:** `TriCoreInstrInfo.td`, lines 486–488

```tablegen
def : Pat<(truncstorei8 ExtRegs:$d, addr:$memri),
     (STWbo (ANDrc (EXTRACT_SUBREG ExtRegs:$d, subreg_even), (i32 255)), addr:$memri)>;
```

This masks the lower byte and then uses `STWbo` (store 32-bit word). Under the
pattern, the surrounding bytes at the target address will be overwritten — a
`truncstorei8` must only write one byte. The correct instruction is `STBbo`.

### 6. `emitEpilogue` does nothing

**File:** `TriCoreFrameLowering.cpp`, lines 127–128

```cpp
void TriCoreFrameLowering::emitEpilogue(MachineFunction &MF,
                                        MachineBasicBlock &MBB) const {}
```

The prologue decrements A10 (stack pointer) but the epilogue never restores it.
Every function that allocates stack space will leave A10 permanently decremented
after returning. This corrupts the stack in any multi-function program.

### 7. Branch analysis entirely commented out — no branch optimization possible

**File:** `TriCoreInstrInfo.cpp`, lines 172–433

`AnalyzeBranch`, `RemoveBranch`, and `InsertBranch` are all commented out. Without
these, LLVM's block placement, tail-call optimization, branch folding, and many
other passes are unable to work on TriCore. The backend cannot optimize control
flow at all.

---

## Serious / High-Priority Issues

### 8. Dead code after early return in `SelectAddr`

**File:** `TriCoreISelDAGToDAG.cpp`, lines 265–286

```cpp
bool TriCoreDAGToDAGISel::SelectAddr(SDValue Addr, SDValue &Base,
                                     SDValue &Offset) {
  return SelectAddr_new(Addr, Base, Offset);

  // Everything below is unreachable:
  if (FrameIndexSDNode *FIN = …) { … }
  …
```

All code after the `return` is unreachable dead code. This suggests `SelectAddr`
was refactored but never cleaned up. The dead fallback logic also contains a
call to `TM.createDataLayout()` which may reference removed API.

### 9. `isLoadFromStackSlot` / `isStoreToStackSlot` always assert

**File:** `TriCoreInstrInfo.cpp`, lines 50–83

```cpp
unsigned TriCoreInstrInfo::isLoadFromStackSlot(...) const {
  assert(0 && "Unimplemented");
  return 0;
}
```

These are called by LLVM's dead-code elimination, register coalescer, and stack
slot coloring passes. Hitting this assertion aborts the compiler on any code
that triggers those queries.

### 10. `storeRegToStackSlot` / `loadRegFromStackSlot` permanently commented out

**File:** `TriCoreInstrInfo.cpp`, lines 120–170

Without these, the register allocator cannot spill virtual registers to the
stack.  Any function that requires spilling will fail at register allocation.

### 11. `TCCH` — global mutable singleton calling-convention hook

**File:** `TriCoreCallingConvHook.h`, line 74; used throughout `TriCoreISelLowering.cpp`

```cpp
extern TriCoreCallingConvHook TCCH;
```

`TCCH` is a process-wide mutable singleton that maintains state across
`LowerFormalArguments` / `LowerCall` / `LowerCallResult` invocations. This is:

- **Not thread-safe:** parallel LTO / parallel compilation units will race on it.
- **Order-dependent:** correctness depends on call sites being visited in a
  specific order relative to their callee function definitions.
- **Fragile:** any inlining, cloning, or reordering of IR can silently corrupt
  the calling convention decisions.

This entire mechanism bypasses LLVM's `CCState` machinery and should be replaced
by properly annotating the calling convention in `TriCoreCallingConv.td`.

### 12. `LowerCall` only handles direct global-address callees

**File:** `TriCoreISelLowering.cpp`, lines 503–505

```cpp
GlobalAddressSDNode *G = dyn_cast<GlobalAddressSDNode>(Callee);
assert(G && "We only support the calling of global addresses");
```

Function pointer calls, virtual method dispatch, and indirect calls through
address registers are all impossible. This assertion will fire whenever an
indirect call is encountered.

### 13. Callee-saved register list is empty vs. `CC_Save` definition

**File:** `TriCoreRegisterInfo.cpp`, lines 46–49

```cpp
const uint16_t *TriCoreRegisterInfo::getCalleeSavedRegs(...) const {
  static const uint16_t CalleeSavedRegs[] = {0};
  return CalleeSavedRegs;
}
```

`CC_Save` in `TriCoreCallingConv.td` lists A2–A7, D0–D7, A11 as callee-saved,
but `getCalleeSavedRegs` returns an empty list. LLVM uses `getCalleeSavedRegs`
(not `CC_Save`) to decide which registers to save/restore around calls. With an
empty list, **no registers are saved** in prologues/epilogues, meaning the ABI
contract is broken for all call boundaries.

### 14. Materialized large-frame offset conflicts with frame pointer register

**File:** `TriCoreFrameLowering.cpp`, lines 74–87

When the stack frame is larger than 0xFFF bytes, `materializeOffset` uses A14
as a scratch register:

```cpp
unsigned OffsetReg = TriCore::A14;
```

However, if the function has a frame pointer (`hasFP` returns true), A14 is
*also* used as the frame pointer (see `getFrameRegister`). Both paths will
simultaneously write to A14, corrupting either the materialized offset or the
frame pointer.

### 15. `CC_Save` callee-saved register list is ABI-incorrect

**File:** `TriCoreCallingConv.td`, lines 52–54

```tablegen
def CC_Save : CalleeSavedRegs<(add A2, A3, A4, A5, A6, A7,
                                   D0, D1, D2, D3, D4, D5, D6, D7, A11)>;
```

Per the TriCore EABI, **upper** registers (A10, A11, D8–D15) are callee-saved;
the **lower** registers (A2–A9, D0–D7) are caller-saved (scratch). The list
here is the inverse of what is correct. This means the compiler will save and
restore registers it doesn't need to, while allowing registers it should preserve
to be clobbered freely.

### 16. Missing DWARF register numbers for data and address registers

**File:** `TriCoreRegisterInfo.td`, lines 57–90

D0–D15 and A0–A15 have no `DwarfRegNum<[...]>` assignments. Only the extended
(E-) registers and the special-purpose registers (PSW, PCXI, PC, FCX) have DWARF
numbers. Without these, debug information (`.debug_frame`, `.eh_frame`,
variable location tracking) is incomplete or incorrect for all general-purpose
registers.

---

## Medium-Priority Issues

### 17. Register allocation priority for D15 is wrong

**File:** `TriCoreRegisterInfo.td`, lines 120–129

```tablegen
def DataRegs : RegisterClass<"TriCore", [i32], 32, (add
    D15,       // listed first = highest allocation priority
    D2, D3, D4, D5, D6, D7, D8, D9, D10, D11, D12, D13, D14,
    D0, D1)>;
```

D15 is the "implicit data register" in TriCore — many 16-bit instructions
implicitly read or write it. Listing it first gives it the *highest* allocation
priority, so the register allocator will prefer D15 for unrelated variables,
causing unexpected implicit-operand interference. D15 should be listed last (or
near last) to be allocated only when no better register is available.

### 18. `subreg_odd` offset not specified

**File:** `TriCoreRegisterInfo.td`, lines 93–94

```tablegen
def subreg_even: SubRegIndex<32> {let Namespace = "TriCore";}
def subreg_odd : SubRegIndex<32> {let Namespace = "TriCore";}
```

Both sub-register indices specify a 32-bit size but neither specifies an
`Offset`. In LLVM's register info, the offset distinguishes which 32-bit half of
a 64-bit register is accessed. `subreg_odd` should have `Offset = 32` to
indicate it covers the high half. Without this, register coalescing and register
scavenging may produce incorrect sub-register loads/stores.

### 19. Only two conditional branch variants implemented

**File:** `TriCoreInstrInfo.td`, lines 764–768

Only `JNZ` (branch-if-not-zero) and `JZ` (branch-if-zero) with 16-bit SBR
format are defined. All the richer 32-bit conditional branches (`JEQ`, `JNE`,
`JGE`, `JLT`, `JGE.U`, `JLT.U` with 15-bit displacement) are commented out.
This forces comparisons to be materialized into a data register (via `CMP`)
before every branch, instead of using the more efficient compare-and-branch form.

### 20. `imml_32_h_32` constraint is too narrow for `ADDi64C`

**File:** `TriCoreInstrInfo.td`, lines 173–181

```tablegen
return (lByte >=-256 && lByte < 256 && hByte >=-256 && hByte < 256);
```

`ADDi64C` is supposed to add a constant 64-bit immediate to a 64-bit register via
ADDX/ADDC. However, the predicate restricts *each* 32-bit half to the range
[−256, 256), far smaller than the 9-bit signed immediate that ADDX/ADDC support
(−256 to 255 is exactly the range, so this is actually correct), but the name
`imml_32_h_32` and contextual use suggest the author intended arbitrary 64-bit
constants to be handled here. Values outside this range silently fall through
to the `ADDi64` pseudo (register form).

### 21. `EXTRrrpw` pattern has incorrect semantics

**File:** `TriCoreInstrInfo.td`, lines 432–434

```tablegen
def EXTRrrpw : RRPW<0x37, 0b10, …,
    [(set DataRegs:$d, (TriCoreextr DataRegs:$s1, immZExt4:$pos, immZExt4:$width))]>;
```

The `EXTR` hardware instruction extracts `width` bits starting at `pos` from a
single source register — the SDNode `TriCoreextr` takes `(src, pos, width)`. But
`DEXTRrrpw` (the double-register extract) uses a different signature
`(DataRegs:$s1, DataRegs:$s2, immZExt4:$pos)` with three operands. The two
instructions are inadvertently mapped through the same `TriCoreextr` SDNode with
inconsistent operand meanings, making the patterns ambiguous.

### 22. `LowerBR_CC` discards the `tricoreCC` value

**File:** `TriCoreISelLowering.cpp`, lines 329–343

```cpp
SDValue tricoreCC;
SDValue Flag = EmitCMP(LHS, RHS, CC, dl, DAG, tricoreCC);
return DAG.getNode(TriCoreISD::BR_CC, dl, …, Flag.getValue(0), tricoreCC, …);
```

`tricoreCC` is always assigned `COND_NE` by `EmitCMP` regardless of the actual
condition code being compiled. The actual condition information (EQ, LT, GE) is
encoded *inside* `Flag` (the result of the `CMP` node), and the branch only fires
when `Flag != 0`. This means all branches are "branch if comparison result
is non-zero" which collapses EQ, NE, GE, LT into the same runtime behavior
dependent on how the CMP result is computed. The design is functional but
convoluted and prevents direct use of the more efficient BRC/BRR instructions.

### 23. `LowerSETCC` passes wrong operands to `SELECT_CC`

**File:** `TriCoreISelLowering.cpp`, lines 354–357

```cpp
SDValue Ops[] = {LHS, RHS, TargetCC, Flag};
return DAG.getNode(TriCoreISD::SELECT_CC, dl, VTs, Ops);
```

The `SELECT_CC` instruction (lowered to `Select8` pseudo) expects
`(TrueVal, FalseVal, CC, FlagVal)`, but here `LHS` and `RHS` (the comparison
inputs) are passed instead of `TrueVal`/`FalseVal`. The `SETCC` result will be
the comparison input, not a boolean 0/1. The correct operands should be
`DAG.getConstant(1, dl, VT)` (true) and `DAG.getConstant(0, dl, VT)` (false).

### 24. `SelectConstant` for i64: falls through when both halves are non-zero

**File:** `TriCoreISelDAGToDAG.cpp`, lines 347–350

```cpp
if (ImmSVal < 0 || (higherByte != 0 && lowerByte != 0)) {
    outs() << "exit\n";
    SelectCode(N);
    return N;
}
```

When both 32-bit halves of a 64-bit immediate are non-zero (e.g. `0x0000000100000001`),
the function calls `SelectCode(N)` and then **returns `N` unmodified**. `SelectCode`
replaces `N` with the selected node, but `N` now points to a dead node; returning
it is incorrect. This likely causes a use-after-free or assertion failure.

### 25. `isPointer()` global state set on STORE, never reset on LOAD

**File:** `TriCoreISelDAGToDAG.cpp`, lines 487–490

```cpp
case ISD::STORE: {
    ptyType = (N->getOperand(1).getSimpleValueType() == MVT::iPTR) ? true : false;
    break;
}
```

The static `ptyType` flag is set when a STORE node is visited, but never cleared
when any other node type follows. If a pointer store is followed by a non-pointer
operation, `isPointer()` still returns `true`, causing the wrong instruction forms
(address-register variants) to be selected for subsequent operands.

---

## Missing Features

### 26. No floating-point support

There are no floating-point register classes, instruction definitions, or
ISelLowering operations for `f32`/`f64`. Any FP computation will be rejected or
crash. TriCore hardware supports IEEE 754 single- and double-precision FP.

### 27. No division or modulo instructions

`SDIV`, `UDIV`, `SREM`, `UREM` are not lowered. The hardware has `DIV`/`DIVU`
instructions. Without them, the compiler cannot compile any integer division.

### 28. No unsigned multiply

Only signed `MUL` is defined. `MULU` (multiply unsigned giving 64-bit result)
and higher-half multiply instructions are absent.

### 29. `LD.A` (load address register) is commented out

**File:** `TriCoreInstrInfo.td`, lines 458–461

```tablegen
//def LDAbo : BOL<0x99, (outs AddrRegs:$d), …>;
```

Without `LD.A`, address values cannot be loaded from memory into address
registers. Pointer indirection through memory will produce incorrect code or
fail selection.

### 30. No indirect/indirect-register call support

Only direct calls to global symbols are handled. There is no `CALLA` (call via
address register) or similar mechanism. C function pointers, C++ virtual dispatch,
and any program that calls through a computed address are unsupported.

### 31. No varargs / variadic function support

`LowerFormalArguments`, `LowerCall`, and `LowerReturn` all assert or
`report_fatal_error` on vararg functions. Standard library functions like
`printf` cannot be called.

### 32. No jump table support

Switch statements with many cases cannot be lowered to jump tables. Only linear
chains of comparisons are generated.

### 33. No tail-call optimization

`CLI.IsTailCall = false` is unconditionally set in `LowerCall`.

### 34. No subtarget variants

Only a single `"generic"` processor is defined. TriCore TC1.3, TC1.6, TC1.6.2,
TC1.8, TC2.x have different feature sets (enhanced floating point, 64-bit MAC,
lockstep execution, etc.) and ideally each should have a named subtarget with
appropriate feature flags.

### 35. No inline assembly support

There is no `ParseInstruction` / inline asm constraint handling. The AsmParser
subdirectory has a `CMakeLists.txt` but appears to be skeletal.

### 36. No epilogue stack restoration

As noted in the critical bug section, `emitEpilogue` is empty, so the stack
pointer is never restored. Closely related: callee-saved register save/restore
is also absent.

### 37. No `CSUB`/`SEL`/`SELN` (conditional data operations) lowering

TriCore has hardware conditional-select and conditional-subtract instructions that
can replace short if/else sequences. None are exposed to the optimizer.

---

## Code Quality / Style Issues

### 38. Extensive debug `outs()` calls in production code paths

The following locations print diagnostic output on every compilation:

| File | Line(s) | Content |
|------|---------|---------|
| `TriCoreInstrInfo.td` | 836 | `INVERT_VAL` SDNodeXForm prints `"vall: "` |
| `TriCoreInstrInfo.td` | 842, 848 | `SHIFTAMT`/`SHIFTAMT_POS` print `"vall: "` |
| `TriCoreInstrInfo.td` | 864 | `imm0_31` PatLeaf prints value |
| `TriCoreISelLowering.cpp` | 142 | `LowerShifts` prints opcode |
| `TriCoreISelLowering.cpp` | 604 | `LowerCallResult` prints pointer flag |
| `TriCoreISelDAGToDAG.cpp` | 331–386 | `SelectConstant` prints values |
| `TriCoreAsmBackend.cpp` | 47 | `adjustFixupValue` prints fixup kind |

All of these should be replaced with `LLVM_DEBUG(dbgs() << …)` or removed.

### 39. `NULL` instead of `nullptr`

**File:** `TriCoreISelLowering.cpp`, line 45

```cpp
return NULL;
```

Should be `nullptr` per LLVM coding standards.

### 40. Commented-out `foreach` register loop

**File:** `TriCoreRegisterInfo.td`, lines 52–55

```tablegen
//foreach i = 0-15 in {
//  def D#i : TriCoreDataReg<i, "D"#i>, DwarfRegNum<[#i]>;
//  def A#i : TriCoreAdrReg<i, "A"#i>;
//}
```

If this were uncommented, DwarfRegNums would be assigned (fixing issue #16) and
the file would be much shorter, but it was apparently abandoned in favour of the
explicit register definitions. The explicit definitions also lack DwarfRegNums,
compounding the problem.

### 41. `useDeprecatedPositionallyEncodedOperands = 1`

**File:** `TriCore.td`, lines 28–30

This deprecated TableGen attribute suppresses warnings about positionally-encoded
operands but does not fix the underlying problem. Future LLVM versions may remove
this escape hatch entirely.

### 42. `TriCoreRegisterInfo.cpp` file header says "LEG Register Information"

**File:** `TriCoreRegisterInfo.cpp`, line 3

```cpp
//===-- TriCoreRegisterInfo.cpp - LEG Register Information ----------------===//
```

Copy-paste artefact from the "LEG" example backend.

### 43. `TriCoreISelAddressMode::dump()` typo

**File:** `TriCoreISelDAGToDAG.cpp`, line 56

```cpp
errs() << "rriCoreISelAddressMode " << this << '\n';
```

Should be `"TriCoreISelAddressMode"`.

### 44. `getTargetNodeName` uses `NULL` return and missing `EXTR` node

**File:** `TriCoreISelLowering.cpp`, lines 43–73

Returns `NULL` for unknown opcodes. Should return `nullptr`. Also, the `EXTR`
opcode is defined in `TriCoreISD` and has a `case` entry, but `LOAD_SYM` and
`MOVEi32` are present in the table yet never emitted by any lowering code (they
appear to be dead remnants).

### 45. `TriCoreCallingConvHook.h` uses `using namespace llvm` in a header

**File:** `TriCoreCallingConvHook.h`, line 25

```cpp
using namespace llvm;
```

This pollutes the namespace of every file that includes this header, which is
contrary to LLVM's established conventions and can cause subtle name collisions.

### 46. `CC_TriCore` passes all `i32` arguments on the stack

**File:** `TriCoreCallingConv.td`, lines 47–48

```tablegen
CCIfType<[i32], CCAssignToStack<4, 4>>,
```

The commented-out line above it would have placed i32 arguments in D4–D7
(the standard TriCore ABI). The current definition passes all integer arguments
on the stack, which is functionally wrong per the ABI and very inefficient.

### 47. Mismatched `s1`/`d` field in `SR` instruction format

**File:** `TriCoreInstrFormats.td`, lines 127–136

```tablegen
class SR<bits<8> op1, bits<4> op2, …> : T16<…> {
  bits<4> op2;   // shadows the class parameter
  bits<4> s1;
  bits<4> d;
  let Inst{15-12} = op2;
  let Inst{11-8}  = s1;
  // 'd' is declared but never placed in the instruction word
}
```

`d` is declared as a field but never assigned to any `Inst` bit range, so the
destination register is lost in the encoding.

### 48. `A0, A1, A8, A9` should likely be reserved

**File:** `TriCoreRegisterInfo.td`, lines 131–143

These registers have system-defined purposes in the TriCore EABI (A0/A1 =
global small-data base, A8/A9 = global address registers used by the linker).
They should typically be reserved (or at least placed at the end of the
allocation order), but they are freely allocatable.

---

## Summary Table

| # | Severity | Area | Description |
|---|----------|------|-------------|
| 1 | **Critical** | Instruction encoding | `SUBXrr` and `ADDXrr` share identical opcode |
| 2 | **Critical** | Instruction encoding | `BRR` format: `s2` field never written |
| 3 | **Critical** | Code generation | `zext` implemented as `sext` — wrong for bit 31 set |
| 4 | **Critical** | Code generation | `sext_inreg i8/i16` lowered to a plain move, no sign-ext |
| 5 | **Critical** | Code generation | `truncstorei8` stores 32-bit word instead of one byte |
| 6 | **Critical** | Frame lowering | `emitEpilogue` is empty — stack pointer never restored |
| 7 | **Critical** | Optimization | Branch analysis (`AnalyzeBranch` etc.) entirely absent |
| 8 | **Serious** | ISelDAGToDAG | Dead code after early `return` in `SelectAddr` |
| 9 | **Serious** | Instruction info | `isLoadFromStackSlot`/`isStoreToStackSlot` always assert |
| 10 | **Serious** | Register spilling | `storeRegToStackSlot`/`loadRegFromStackSlot` commented out |
| 11 | **Serious** | Calling convention | Global mutable TCCH hook — thread-unsafe, fragile |
| 12 | **Serious** | Call lowering | Only direct global-address calls supported |
| 13 | **Serious** | Register saving | `getCalleeSavedRegs` returns empty — no CSR save/restore |
| 14 | **Serious** | Frame lowering | Large frame offset uses A14, conflicts with FP register |
| 15 | **Serious** | Calling convention | `CC_Save` list has inverted callee/caller-saved semantics |
| 16 | **Serious** | Debug info | DWARF register numbers missing for D0–D15 and A0–A15 |
| 17 | Medium | Register alloc | D15 (implicit reg) has highest allocation priority |
| 18 | Medium | Register info | `subreg_odd` offset unspecified |
| 19 | Medium | Code generation | Only 2 conditional branch forms — inefficient compare-branch |
| 20 | Medium | Patterns | `imml_32_h_32` immediate constraint confusing |
| 21 | Medium | Patterns | `EXTRrrpw` and `DEXTRrrpw` share ambiguous `TriCoreextr` node |
| 22 | Medium | ISelLowering | `LowerBR_CC` always emits `COND_NE` branch condition |
| 23 | Medium | ISelLowering | `LowerSETCC` passes comparison inputs instead of 1/0 |
| 24 | Medium | ISelDAGToDAG | `SelectConstant` i64 returns dead node when both halves non-zero |
| 25 | Medium | ISelDAGToDAG | `isPointer` global flag not reset between nodes |
| 26 | Missing | FP | No floating-point support |
| 27 | Missing | Arithmetic | No division/modulo lowering |
| 28 | Missing | Arithmetic | No unsigned multiply |
| 29 | Missing | Load/store | `LD.A` (load address register) commented out |
| 30 | Missing | Call lowering | No indirect/function-pointer calls |
| 31 | Missing | ABI | No varargs support |
| 32 | Missing | Optimization | No jump table lowering |
| 33 | Missing | Optimization | No tail-call optimization |
| 34 | Missing | Subtargets | Only one generic processor, no TC1.x / TC2.x variants |
| 35 | Missing | Assembly | No inline assembly constraint handling |
| 36 | Missing | Frame | No callee-saved register save/restore in prologue/epilogue |
| 37 | Missing | Instructions | No `CSUB`/`SEL`/`SELN` conditional operations |
| 38 | Quality | Debugging | `outs()` debug prints scattered throughout production paths |
| 39 | Quality | Style | `NULL` used instead of `nullptr` |
| 40 | Quality | TableGen | Commented-out `foreach` loop for register definitions |
| 41 | Quality | TableGen | `useDeprecatedPositionallyEncodedOperands` used |
| 42 | Quality | Style | Copy-paste header comment "LEG Register Information" |
| 43 | Quality | Style | Typo `"rriCoreISelAddressMode"` in debug dump |
| 44 | Quality | ISelLowering | Dead `LOAD_SYM`/`MOVEi32` in `getTargetNodeName` |
| 45 | Quality | Style | `using namespace llvm` in a header file |
| 46 | Quality | Calling conv | All `i32` args passed on stack instead of in registers |
| 47 | Quality | Encoding | `SR` format: `d` field declared but never placed in encoding |
| 48 | Quality | Registers | System-reserved A0/A1/A8/A9 freely allocatable |

---

*End of analysis.*
