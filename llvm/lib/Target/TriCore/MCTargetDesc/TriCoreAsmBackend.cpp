//===-- TriCoreAsmBackend.cpp - TriCore Assembler Backend -----------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "TriCoreAsmBackend.h"
#include "MCTargetDesc/TriCoreFixupKinds.h"
#include "MCTargetDesc/TriCoreMCTargetDesc.h"
#include "llvm/ADT/StringSwitch.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDirectives.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixupKindInfo.h"
#include "llvm/MC/MCMachObjectWriter.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/MC/MCSectionMachO.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/MCValue.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/ErrorHandling.h"
// #include "llvm/Support/MachO.h"
#include "llvm/Support/raw_ostream.h"
using namespace llvm;

namespace {
class TriCoreELFObjectWriter : public MCELFObjectTargetWriter {
public:
  TriCoreELFObjectWriter(uint8_t OSABI)
      : MCELFObjectTargetWriter(/*Is64Bit*/ false, OSABI,
                                /*ELF::EM_TriCore*/ ELF::EM_TRICORE,
                                /*HasRelocationAddend*/ false) {}
};

} // end anonymous namespace

static unsigned adjustFixupValue(const MCFixup &Fixup, uint64_t Value,
                                 MCContext *Ctx = NULL) {
  unsigned Kind = Fixup.getKind();
  switch (Kind) {
  default:
    // Standard fixup kinds (FK_Data_1/2/4, FK_PCRel_*) need no adjustment.
    return Value;
  case TriCore::fixup_tricore_branch16:
    return Value & 0xffff;
  case TriCore::fixup_call:
    return Value & 0xffffff;
  case TriCore::fixup_tricore_mov_hi16_pcrel:
    Value >>= 16;
  // Intentional fall-through
  case TriCore::fixup_tricore_mov_lo16_pcrel:
    unsigned Hi4 = (Value & 0xF000) >> 12;
    unsigned Lo12 = Value & 0x0FFF;
    // inst{19-16} = Hi4;
    // inst{11-0} = Lo12;
    Value = (Hi4 << 16) | (Lo12);
    return Value;
  }
  return Value;
}

void TriCoreAsmBackend::processFixupValue(const MCAssembler &Asm,
                                          const MCAsmLayout &Layout,
                                          const MCFixup &Fixup,
                                          const MCFragment *DF,
                                          const MCValue &Target,
                                          uint64_t &Value, bool &IsResolved) {
  // Only validate TriCore-specific fixups; let standard fixup kinds (FK_Data_*,
  // FK_PCRel_*) be resolved by the default assembler machinery.
  if (Fixup.getKind() >= FirstTargetFixupKind)
    (void)adjustFixupValue(Fixup, Value, &Asm.getContext());
}

void TriCoreAsmBackend::applyFixup(const MCAssembler &Asm, const MCFixup &Fixup,
                                   const MCValue &Target,
                                   MutableArrayRef<char> Data, uint64_t Value,
                                   bool IsResolved,
                                   const MCSubtargetInfo *STI) const {
  // Use the actual byte width of the fixup from the kind info.
  MCFixupKind Kind = Fixup.getKind();
  unsigned NumBytes = (getFixupKindInfo(Kind).TargetSize + 7) / 8;
  Value = adjustFixupValue(Fixup, Value);
  if (!Value) {
    return; // Doesn't change encoding.
  }

  unsigned Offset = Fixup.getOffset();
  assert(Offset + NumBytes <= Data.size() && "Invalid fixup offset!");

  // For each byte of the fragment that the fixup touches, mask in the bits from
  // the fixup value. The Value has been "split up" into the appropriate
  // bitfields above.
  for (unsigned i = 0; i != NumBytes; ++i) {
    Data[Offset + i] |= uint8_t((Value >> (i * 8)) & 0xff);
  }
}

std::unique_ptr<MCObjectTargetWriter>
TriCoreAsmBackend::createObjectTargetWriter() const {
  return createTriCoreELFObjectWriter(OSABI);
}

MCAsmBackend *llvm::createTriCoreAsmBackend(const Target &T,
                                            const MCSubtargetInfo &STI,
                                            const MCRegisterInfo &MRI,
                                            const MCTargetOptions &Options) {
  const uint8_t ABI = MCELFObjectTargetWriter::getOSABI(STI.getTargetTriple().getOS());
  return new TriCoreAsmBackend(T, STI.getTargetTriple(), ABI);
}
