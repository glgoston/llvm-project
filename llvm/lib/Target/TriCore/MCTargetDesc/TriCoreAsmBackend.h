//===-- TriCoreAsmBackend.h - TriCore Assembler Backend -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_TRICORE_MCTARGETDESC_TRICOREASMBACKEND_H
#define LLVM_LIB_TARGET_TRICORE_MCTARGETDESC_TRICOREASMBACKEND_H

#include "MCTargetDesc/TriCoreFixupKinds.h"
#include "MCTargetDesc/TriCoreMCTargetDesc.h"
// #include "Utils/RISCVBaseInfo.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCFixupKindInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"

namespace llvm {
class MCAssembler;
class MCObjectTargetWriter;
class raw_ostream;

class TriCoreAsmBackend : public MCAsmBackend {
  uint8_t OSABI;

public:
  TriCoreAsmBackend(const Target &T, const Triple &TT, uint8_t _OSABI)
      : MCAsmBackend(support::little), OSABI(_OSABI) {}

  ~TriCoreAsmBackend() {}

  unsigned getNumFixupKinds() const override {
    return TriCore::NumTargetFixupKinds;
  }

  const MCFixupKindInfo &getFixupKindInfo(MCFixupKind Kind) const override {
    const static MCFixupKindInfo Infos[TriCore::NumTargetFixupKinds] = {
        // This table *must* be in the order that the fixup_* kinds are defined
        // in TriCoreFixupKinds.h.
        //
        // Name                      Offset (bits) Size (bits)     Flags
        {"fixup_leg_mov_hi16_pcrel", 0, 32, MCFixupKindInfo::FKF_IsPCRel},
        {"fixup_leg_mov_lo16_pcrel", 0, 32, MCFixupKindInfo::FKF_IsPCRel},
        {"fixup_call",              0, 24, 0},
        {"fixup_tricore_branch16",  0, 16, MCFixupKindInfo::FKF_IsPCRel},
    };

    if (Kind < FirstTargetFixupKind) {
      return MCAsmBackend::getFixupKindInfo(Kind);
    }

    assert(unsigned(Kind - FirstTargetFixupKind) < getNumFixupKinds() &&
           "Invalid kind!");
    return Infos[Kind - FirstTargetFixupKind];
  }

  /// processFixupValue - Target hook to process the literal value of a fixup
  /// if necessary.
  void processFixupValue(const MCAssembler &Asm, const MCAsmLayout &Layout,
                         const MCFixup &Fixup, const MCFragment *DF,
                         const MCValue &Target, uint64_t &Value,
                         bool &IsResolved);

  void applyFixup(const MCAssembler &Asm, const MCFixup &Fixup,
                  const MCValue &Target, MutableArrayRef<char> Data,
                  uint64_t Value, bool IsResolved,
                  const MCSubtargetInfo *STI) const override;

  bool fixupNeedsRelaxation(const MCFixup &Fixup, uint64_t Value,
                            const MCRelaxableFragment *DF,
                            const MCAsmLayout &Layout) const override {
    return false;
  }

  bool writeNopData(raw_ostream &OS, uint64_t Count,
                    const MCSubtargetInfo *STI) const override {
    if (Count == 0) {
      return true;
    }
    return false;
  }

  unsigned getPointerSize() const { return 4; }

  std::unique_ptr<MCObjectTargetWriter>
  createObjectTargetWriter() const override;
};

} // namespace llvm

#endif