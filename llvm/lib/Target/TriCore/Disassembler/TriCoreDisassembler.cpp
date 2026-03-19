//===-- TriCoreDisassembler.cpp - Disassembler for TriCore ------*- C++ -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the TriCoreDisassembler class, which translates raw
// instruction bytes into MCInst objects for the TriCore v1.6 ISA.
//
// Instruction width detection:
//   bit 0 of Bytes[0] == 0  →  16-bit short instruction (T16 / SRC, SRR, SC,
//                                                         SB, SBR, SR formats)
//   bit 0 of Bytes[0] == 1  →  32-bit instruction (all other formats)
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/TriCoreMCTargetDesc.h"
#include "TargetInfo/TriCoreTargetInfo.h"
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

// ---------------------------------------------------------------------------
// Disassembler class
// ---------------------------------------------------------------------------

namespace {
class TriCoreDisassembler : public MCDisassembler {
public:
  TriCoreDisassembler(const MCSubtargetInfo &STI, MCContext &Ctx)
      : MCDisassembler(STI, Ctx) {}

  DecodeStatus getInstruction(MCInst &Instr, uint64_t &Size,
                              ArrayRef<uint8_t> Bytes, uint64_t Address,
                              raw_ostream &CStream) const override;
};
} // end anonymous namespace

static MCDisassembler *createTriCoreDisassembler(const Target & /*T*/,
                                                  const MCSubtargetInfo &STI,
                                                  MCContext &Ctx) {
  return new TriCoreDisassembler(STI, Ctx);
}

extern "C" LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeTriCoreDisassembler() {
  TargetRegistry::RegisterMCDisassembler(getTheTriCoreTarget(),
                                         createTriCoreDisassembler);
}

// ---------------------------------------------------------------------------
// Raw byte readers
// ---------------------------------------------------------------------------

static bool readInstruction16(ArrayRef<uint8_t> Bytes, uint64_t &Size,
                               uint16_t &Insn) {
  if (Bytes.size() < 2) {
    Size = 0;
    return false;
  }
  // TriCore is little-endian.
  Insn = static_cast<uint16_t>(Bytes[0]) |
         (static_cast<uint16_t>(Bytes[1]) << 8);
  return true;
}

static bool readInstruction32(ArrayRef<uint8_t> Bytes, uint64_t &Size,
                               uint32_t &Insn) {
  if (Bytes.size() < 4) {
    Size = 0;
    return false;
  }
  // TriCore is little-endian.
  Insn = static_cast<uint32_t>(Bytes[0])        |
         (static_cast<uint32_t>(Bytes[1]) <<  8) |
         (static_cast<uint32_t>(Bytes[2]) << 16) |
         (static_cast<uint32_t>(Bytes[3]) << 24);
  return true;
}

// ---------------------------------------------------------------------------
// Register-class decoder tables
// ---------------------------------------------------------------------------

// DataRegs: D0–D15, hardware-encoded as 0–15.
static const unsigned DataRegDecoderTable[] = {
  TriCore::D0,  TriCore::D1,  TriCore::D2,  TriCore::D3,
  TriCore::D4,  TriCore::D5,  TriCore::D6,  TriCore::D7,
  TriCore::D8,  TriCore::D9,  TriCore::D10, TriCore::D11,
  TriCore::D12, TriCore::D13, TriCore::D14, TriCore::D15
};

static DecodeStatus DecodeDataRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                                uint64_t /*Addr*/,
                                                const MCDisassembler * /*Dec*/) {
  if (RegNo > 15)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(DataRegDecoderTable[RegNo]));
  return MCDisassembler::Success;
}

// AddrRegs: A0–A15, hardware-encoded as 0–15.
static const unsigned AddrRegDecoderTable[] = {
  TriCore::A0,  TriCore::A1,  TriCore::A2,  TriCore::A3,
  TriCore::A4,  TriCore::A5,  TriCore::A6,  TriCore::A7,
  TriCore::A8,  TriCore::A9,  TriCore::A10, TriCore::A11,
  TriCore::A12, TriCore::A13, TriCore::A14, TriCore::A15
};

static DecodeStatus DecodeAddrRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                                uint64_t /*Addr*/,
                                                const MCDisassembler * /*Dec*/) {
  if (RegNo > 15)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(AddrRegDecoderTable[RegNo]));
  return MCDisassembler::Success;
}

// ExtRegs: E0, E2, E4, E6, E8, E10, E12, E14.
// The instruction field encodes the even sub-register number (0, 2, …, 14).
static const unsigned ExtRegDecoderTable[] = {
  TriCore::E0,  TriCore::E2,  TriCore::E4,  TriCore::E6,
  TriCore::E8,  TriCore::E10, TriCore::E12, TriCore::E14
};

static DecodeStatus DecodeExtRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                               uint64_t /*Addr*/,
                                               const MCDisassembler * /*Dec*/) {
  // Valid values: 0, 2, 4, 6, 8, 10, 12, 14 (even, 0–14).
  if (RegNo > 14 || (RegNo & 1))
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(ExtRegDecoderTable[RegNo >> 1]));
  return MCDisassembler::Success;
}

// PSRegs – system status registers. Not typically decoded in user code,
// but needed so TableGen-generated tables compile.
static DecodeStatus DecodePSRegsRegisterClass(MCInst &Inst, unsigned RegNo,
                                              uint64_t /*Addr*/,
                                              const MCDisassembler * /*Dec*/) {
  static const unsigned PSRegTable[] = {
    TriCore::PSW, TriCore::PCXI, TriCore::PC, TriCore::FCX
  };
  if (RegNo > 3)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(PSRegTable[RegNo]));
  return MCDisassembler::Success;
}

// ---------------------------------------------------------------------------
// Custom composite operand decoders
// ---------------------------------------------------------------------------

// decodeMemSrcValue – BO format (10-bit signed offset).
//
// The TableGen encoder packs the memsrc operand as:
//   combined = (offset_signed << 4) | base_reg_index
// For BO instructions the combined field is 14 bits wide:
//   bits [3:0]  = base address register index (0–15)
//   bits [13:4] = 10-bit signed offset
// The inverse:
//   base reg  = val & 0xF
//   offset    = SignExtend32<10>(val >> 4)
static DecodeStatus decodeMemSrcValue(MCInst &Inst, unsigned Val,
                                      uint64_t /*Addr*/,
                                      const MCDisassembler * /*Dec*/) {
  unsigned BaseReg = Val & 0xF;
  int32_t  Offset  = SignExtend32<10>(Val >> 4);
  if (BaseReg > 15)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(AddrRegDecoderTable[BaseReg]));
  Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}

// decodeBOLMemSrcValue – BOL format (16-bit signed offset).
//
// The BOL memsrc field is 20 bits wide:
//   bits [3:0]  = base address register index (0–15)
//   bits [19:4] = 16-bit signed offset
// The inverse:
//   base reg  = val & 0xF
//   offset    = SignExtend32<16>(val >> 4)
static DecodeStatus decodeBOLMemSrcValue(MCInst &Inst, unsigned Val,
                                          uint64_t /*Addr*/,
                                          const MCDisassembler * /*Dec*/) {
  unsigned BaseReg = Val & 0xF;
  int32_t  Offset  = SignExtend32<16>(Val >> 4);
  if (BaseReg > 15)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(AddrRegDecoderTable[BaseReg]));
  Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}

// ---------------------------------------------------------------------------
// TableGen-generated decode tables
// Must appear after all forward-declared decoder functions.
// ---------------------------------------------------------------------------

#include "TriCoreGenDisassemblerTable.inc"

// ---------------------------------------------------------------------------
// getInstruction
// ---------------------------------------------------------------------------

DecodeStatus TriCoreDisassembler::getInstruction(MCInst &Instr, uint64_t &Size,
                                                  ArrayRef<uint8_t> Bytes,
                                                  uint64_t Address,
                                                  raw_ostream & /*CStream*/) const {
  if (Bytes.empty()) {
    Size = 0;
    return Fail;
  }

  // TriCore instruction width detection: bit 0 of the first byte.
  //   0 → 16-bit short instruction
  //   1 → 32-bit instruction
  if (!(Bytes[0] & 0x01)) {
    uint16_t Insn16;
    if (!readInstruction16(Bytes, Size, Insn16))
      return Fail;
    DecodeStatus Result =
        decodeInstruction(DecoderTableTriCore1616, Instr, Insn16,
                          Address, this, STI);
    if (Result != MCDisassembler::Fail) {
      Size = 2;
      return Result;
    }
    Size = 2; // consume the bytes even if decoding failed
    return MCDisassembler::Fail;
  }

  uint32_t Insn32;
  if (!readInstruction32(Bytes, Size, Insn32))
    return Fail;
  DecodeStatus Result =
      decodeInstruction(DecoderTableTriCore32, Instr, Insn32,
                        Address, this, STI);
  if (Result != MCDisassembler::Fail) {
    Size = 4;
    return Result;
  }
  Size = 4;
  return MCDisassembler::Fail;
}
