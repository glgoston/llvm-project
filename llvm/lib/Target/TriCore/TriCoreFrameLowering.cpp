//=-- TriCoreFrameLowering.cpp - Frame info for TriCore Target ------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file contains TriCore frame information that doesn't fit anywhere else
// cleanly...
//
//===----------------------------------------------------------------------===//

#include "TriCoreFrameLowering.h"
#include "TriCore.h"
#include "TriCoreInstrInfo.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/RegisterScavenging.h"
#include "llvm/CodeGen/TargetLowering.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Function.h"
#include "llvm/MC/MCDwarf.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Target/TargetOptions.h"
#include <algorithm> // std::sort

using namespace llvm;

//===----------------------------------------------------------------------===//
// TriCoreFrameLowering:
//===----------------------------------------------------------------------===//
TriCoreFrameLowering::TriCoreFrameLowering()
    : TargetFrameLowering(TargetFrameLowering::StackGrowsDown, Align(8), 0) {
  // Do nothing
}

bool TriCoreFrameLowering::hasFP(const MachineFunction &MF) const {
  const auto& MFI = MF.getFrameInfo();

  return (MF.getTarget().Options.DisableFramePointerElim(MF) ||
          MFI.hasVarSizedObjects() || MFI.isFrameAddressTaken());
}

uint64_t TriCoreFrameLowering::computeStackSize(MachineFunction &MF) const {
  const auto& MFI = MF.getFrameInfo();
  uint64_t StackSize = MFI.getStackSize();
  StackSize = alignSPAdjust(StackSize);

  return StackSize;
}

// Materialize an offset for a ADD/SUB stack operation.
// Return zero if the offset fits into the instruction as an immediate,
// or the number of the register where the offset is materialized.
static unsigned materializeOffset(MachineFunction &MF, MachineBasicBlock &MBB,
                                  MachineBasicBlock::iterator MBBI,
                                  unsigned Offset,
                                  unsigned ScratchReg = TriCore::A12) {
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  DebugLoc dl = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  // SUBAsc uses u8imm (0-255); anything larger must go through a register.
  const uint64_t MaxSubImm = 0xff;

  if (Offset <= MaxSubImm) {
    // The stack offset fits in the ADD/SUB instruction.
    return 0;
  } else {
    // The stack offset does not fit in the ADD/SUB instruction.
    // Materialize the offset into a data register first (MOVrlc outputs
    // DataRegs), then move it into the address scratch register via MOVArr.
    unsigned DataScratch = TriCore::D15;
    unsigned OffsetLo = (unsigned)(Offset & 0xffff);
    unsigned OffsetHi = (unsigned)((Offset & 0xffff0000) >> 16);
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVrlc), DataScratch)
        .addImm(OffsetLo)
        .setMIFlag(MachineInstr::FrameSetup);
    if (OffsetHi) {
      BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVHrlc), DataScratch)
          .addReg(DataScratch)
          .addImm(OffsetHi)
          .setMIFlag(MachineInstr::FrameSetup);
    }
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVArr), ScratchReg)
        .addReg(DataScratch)
        .setMIFlag(MachineInstr::FrameSetup);
    return ScratchReg;
  }
}

void TriCoreFrameLowering::emitPrologue(MachineFunction &MF,
                                        MachineBasicBlock &MBB) const {
  // Compute the stack size, to determine if we need a prologue at all.
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  MachineBasicBlock::iterator MBBI = MBB.begin();
  DebugLoc dl = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  MachineModuleInfo &MMI = MF.getMMI();
  const MCRegisterInfo *MRI = MMI.getContext().getRegisterInfo();
  // const TargetFrameLowering *TFI = MF.getSubtarget().getFrameLowering();
  uint64_t StackSize = computeStackSize(MF);
  if (!StackSize) {
    return;
  }

  if (hasFP(MF)) {
    // mov.a A14, A10  — save current SP to FP
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVAAsrr), TriCore::A14)
        .addReg(TriCore::A10)
        .setMIFlag(MachineInstr::FrameSetup);

    // Emit CFI for frame pointer setup
    // DW_CFA_def_cfa_register: CFA is now defined relative to A14 (FP)
    unsigned CFIIndex = MF.addFrameInst(
        MCCFIInstruction::createDefCfaRegister(nullptr,
                                                MRI->getDwarfRegNum(TriCore::A14, true)));
    BuildMI(MBB, MBBI, dl, TII.get(TargetOpcode::CFI_INSTRUCTION))
        .addCFIIndex(CFIIndex)
        .setMIFlag(MachineInstr::FrameSetup);

    // Mark the FramePtr as live-in in every block except the entry
    MachineFunction::iterator I;
    for (I = std::next(MF.begin()); I != MF.end(); ++I)
      I->addLiveIn(TriCore::A14);
  }

  // Adjust the stack pointer.
  unsigned StackReg = TriCore::A10;
  unsigned OffsetReg = materializeOffset(MF, MBB, MBBI, (unsigned)StackSize);
  if (OffsetReg) {
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::SUBArr), StackReg)
        .addReg(StackReg)
        .addReg(OffsetReg)
        .setMIFlag(MachineInstr::FrameSetup);
  } else {
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::SUBAsc))
        .addImm(StackSize)
        .setMIFlag(MachineInstr::FrameSetup);
  }

  // Emit CFI for stack pointer adjustment
  // DW_CFA_def_cfa_offset: CFA offset is now StackSize
  unsigned CFIIndex = MF.addFrameInst(
      MCCFIInstruction::cfiDefCfaOffset(nullptr, StackSize));
  BuildMI(MBB, MBBI, dl, TII.get(TargetOpcode::CFI_INSTRUCTION))
      .addCFIIndex(CFIIndex)
      .setMIFlag(MachineInstr::FrameSetup);
}

void TriCoreFrameLowering::emitEpilogue(MachineFunction &MF,
                                        MachineBasicBlock &MBB) const {
  const TargetInstrInfo &TII = *MF.getSubtarget().getInstrInfo();
  MachineBasicBlock::iterator MBBI = MBB.getLastNonDebugInstr();
  DebugLoc dl = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  uint64_t StackSize = computeStackSize(MF);
  if (!StackSize)
    return;

  unsigned StackReg = TriCore::A10;

  if (hasFP(MF)) {
    // Frame pointer is A14: restore SP from FP in a single instruction.
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVAArr), StackReg)
        .addReg(TriCore::A14)
        .setMIFlag(MachineInstr::FrameDestroy);
    return;
  }

  // No frame pointer: add StackSize back to SP.
  unsigned OffsetReg = materializeOffset(MF, MBB, MBBI, (unsigned)StackSize);
  if (OffsetReg) {
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::ADDArr), StackReg)
        .addReg(StackReg)
        .addReg(OffsetReg)
        .setMIFlag(MachineInstr::FrameDestroy);
  } else {
    // StackSize fits in a 9-bit signed immediate: use ADDrc on D15,
    // then convert to address register A12 and add.a to SP.
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::ADDrc), TriCore::D15)
        .addReg(TriCore::D15, RegState::Undef)
        .addImm(StackSize)
        .setMIFlag(MachineInstr::FrameDestroy);
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::MOVArr), TriCore::A12)
        .addReg(TriCore::D15)
        .setMIFlag(MachineInstr::FrameDestroy);
    BuildMI(MBB, MBBI, dl, TII.get(TriCore::ADDArr), StackReg)
        .addReg(StackReg)
        .addReg(TriCore::A12)
        .setMIFlag(MachineInstr::FrameDestroy);
  }
}

// This function eliminates ADJCALLSTACKDOWN, ADJCALLSTACKUP pseudo
// instructions
MachineBasicBlock::iterator TriCoreFrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator I) const {
  if (I->getOpcode() == TriCore::ADJCALLSTACKUP ||
      I->getOpcode() == TriCore::ADJCALLSTACKDOWN) {
    return MBB.erase(I);
  }
  return I;
}
