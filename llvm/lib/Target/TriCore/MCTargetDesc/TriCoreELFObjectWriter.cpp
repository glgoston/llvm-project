//===-- TriCoreELFObjectWriter.cpp - TriCore ELF Writer -------------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/TriCoreFixupKinds.h"
#include "MCTargetDesc/TriCoreMCTargetDesc.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
class TriCoreELFObjectWriter : public MCELFObjectTargetWriter {
public:
  TriCoreELFObjectWriter(uint8_t OSABI);

  virtual ~TriCoreELFObjectWriter();

  unsigned getRelocType(MCContext &Ctx, const MCValue &Target,
                        const MCFixup &Fixup, bool IsPCRel) const override;
};
} // namespace

unsigned TriCoreELFObjectWriter::getRelocType(MCContext &Ctx,
                                              const MCValue &Target,
                                              const MCFixup &Fixup,
                                              bool IsPCRel) const {
  unsigned Type = 0;
  switch ((unsigned)Fixup.getKind()) {
  default:
    llvm_unreachable("Unknown TriCore fixup kind");
  // Standard data/section fixup kinds — used for .word/.long symbol refs,
  // jump tables, and constant pools.
  case FK_Data_1:
    // No R_TRICORE_8ABS defined; treat as 16-bit absolute (best effort).
    return ELF::R_TRICORE_16ABS;
  case FK_Data_2:
    return ELF::R_TRICORE_16ABS;
  case FK_Data_4:
    return IsPCRel ? ELF::R_TRICORE_32REL : ELF::R_TRICORE_32ABS;
  case FK_PCRel_4:
    return ELF::R_TRICORE_32REL;
  case TriCore::fixup_tricore_branch16:
    // 16-bit PC-relative branch (JZ, JNZ, SB, SBR instructions)
    Type = ELF::R_TRICORE_16REL;
    break;
  case TriCore::fixup_call:
    // 24-bit PC-relative function call (CALL instruction)
    Type = ELF::R_TRICORE_24REL;
    break;
  case TriCore::fixup_tricore_mov_hi16_pcrel:
    // Upper 16-bit of PC-relative address (MOVH.A instruction)
    Type = ELF::R_TRICORE_PCHI;
    break;
  case TriCore::fixup_tricore_mov_lo16_pcrel:
    // Lower 16-bit of PC-relative address (LEA instruction)
    Type = ELF::R_TRICORE_PCLO;
    break;
  }
  return Type;
}

TriCoreELFObjectWriter::TriCoreELFObjectWriter(uint8_t OSABI)
    : MCELFObjectTargetWriter(/*Is64Bit*/ false, OSABI,
                              /*ELF::EM_TriCore*/ ELF::EM_TRICORE,
                              /*HasRelocationAddend*/ false) {}

TriCoreELFObjectWriter::~TriCoreELFObjectWriter() {}

std::unique_ptr<MCObjectTargetWriter>
llvm::createTriCoreELFObjectWriter(uint8_t OSABI) {
  return std::make_unique<TriCoreELFObjectWriter>(OSABI);
}