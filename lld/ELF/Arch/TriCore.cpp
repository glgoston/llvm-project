//===- TriCore.cpp --------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// TriCore is a 32-bit RISC/DSP hybrid microcontroller architecture designed
// by Infineon Technologies for automotive and industrial embedded systems.
// The architecture features a Harvard architecture with separate program
// and data memories, three independent execution units (Load/Store, Integer,
// Loop), and extensive DSP capabilities.
//
// TriCore uses 16-bit and 32-bit variable-length instructions. Most
// instructions are 32-bit aligned, but some 16-bit instructions can appear
// in pairs. The architecture supports up to 4GB address space and features
// comprehensive interrupt handling suitable for real-time applications.
//
// This file implements the LLD linker support for TriCore ELF objects,
// handling relocations for both absolute and position-independent code.
//
//===----------------------------------------------------------------------===//

#include "Symbols.h"
#include "Target.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::object;
using namespace llvm::support::endian;
using namespace llvm::ELF;
using namespace lld;
using namespace lld::elf;

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

TriCore::TriCore() {
  // NOP instruction (no operation): 0x00000000
  trapInstr = {0x00, 0x00, 0x00, 0x00};
}

RelExpr TriCore::getRelExpr(RelType type, const Symbol &s,
                             const uint8_t *loc) const {
  switch (type) {
  // PC-relative relocations
  case R_TRICORE_16REL:
  case R_TRICORE_24REL:
  case R_TRICORE_32REL:
  case R_TRICORE_PCHI:
  case R_TRICORE_PCLO:
    return R_PC;
  
  // Absolute relocations
  case R_TRICORE_16SM:
  case R_TRICORE_16ABS:
  case R_TRICORE_32ABS:
  case R_TRICORE_HI:
  case R_TRICORE_LO:
    return R_ABS;
  
  // No relocation needed (e.g., section-relative)
  case R_TRICORE_NONE:
    return R_NONE;
  
  default:
    error(getErrorLocation(loc) + "unknown relocation (" + Twine(type) +
          ") against symbol " + toString(s));
    return R_NONE;
  }
}

void TriCore::relocate(uint8_t *loc, const Relocation &rel, uint64_t val) const {
  switch (rel.type) {
  case R_TRICORE_NONE:
    break;

  // 16-bit signed with modulo relocation
  case R_TRICORE_16SM:
    checkInt(loc, val, 16, rel);
    write16le(loc, val);
    break;

  // 16-bit absolute relocation
  case R_TRICORE_16ABS:
    checkUInt(loc, val, 16, rel);
    write16le(loc, val);
    break;

  // 32-bit absolute relocation
  case R_TRICORE_32ABS:
    write32le(loc, val);
    break;

  // 32-bit PC-relative relocation
  case R_TRICORE_32REL:
    write32le(loc, val);
    break;

  // 24-bit PC-relative relocation (CALL/J instructions)
  // Encoding: bits [31:8] of instruction, value is (S-P)/2
  // The instruction offset is already computed by the caller (val = S-P),
  // so we divide by 2 and place in bits [31:8]
  case R_TRICORE_24REL: {
    // TriCore branches have 2-byte granularity (instructions are aligned)
    checkAlignment(loc, val, 2, rel);
    
    // Check byte offset range first (±2^24 bytes = ±16MB)
    checkInt(loc, val, 25, rel);
    
    // Convert byte offset to instruction offset (divide by 2)
    int64_t offset = (int64_t)val / 2;
    
    // Read the existing instruction (32-bit little-endian)
    uint32_t insn = read32le(loc);
    
    // Clear bits [31:8] and insert the new offset (24 bits)
    insn = (insn & 0x000000FF) | ((offset & 0x00FFFFFF) << 8);
    
    write32le(loc, insn);
    break;
  }

  // 16-bit PC-relative relocation (conditional branches: JNZ, JZ, etc.)
  // Encoding: bits [11:8] of instruction (4 bits!), value is (S-P)/2
  case R_TRICORE_16REL: {
    // TriCore branches have 2-byte granularity
    checkAlignment(loc, val, 2, rel);
    
    // Convert byte offset to instruction offset (divide by 2)
    // Sign-extend from the PC-relative displacement
    int64_t offset = SignExtend64<17>(val) / 2;
    
    // Check that the offset fits in 4 bits (signed: -8 to +7 instructions)
    checkInt(loc, offset, 4, rel);
    
    // Read the existing instruction (16-bit little-endian)
    uint16_t insn = read16le(loc);
    
    // Clear bits [11:8] and insert the new offset (4 bits)
    insn = (insn & 0xF0FF) | ((offset & 0x0F) << 8);
    
    write16le(loc, insn);
    break;
  }

  // Upper 16 bits of PC-relative address (MOVH.A instruction)
  // Encoding: bits [27:12] of instruction
  case R_TRICORE_PCHI: {
    uint32_t insn = read32le(loc);
    
    // Extract upper 16 bits of the PC-relative value
    uint32_t hi16 = (val >> 16) & 0xFFFF;
    
    // Clear bits [27:12] and insert the high 16 bits
    insn = (insn & 0xF000'0FFF) | (hi16 << 12);
    
    write32le(loc, insn);
    break;
  }

  // Lower 16 bits of PC-relative address (LEA instruction)
  // Encoding: bits [27:12] of instruction
  case R_TRICORE_PCLO: {
    uint32_t insn = read32le(loc);
    
    // Extract lower 16 bits of the PC-relative value
    uint32_t lo16 = val & 0xFFFF;
    
    // Clear bits [27:12] and insert the low 16 bits
    insn = (insn & 0xF000'0FFF) | (lo16 << 12);
    
    write32le(loc, insn);
    break;
  }

  // High and low 16-bit absolute relocations (for CONST16 pair)
  case R_TRICORE_HI:
    write16le(loc, (val >> 16) & 0xFFFF);
    break;

  case R_TRICORE_LO:
    write16le(loc, val & 0xFFFF);
    break;

  default:
    error(getErrorLocation(loc) + "unrecognized relocation " +
          toString(rel.type));
  }
}

TargetInfo *elf::getTriCoreTargetInfo() {
  static TriCore target;
  return &target;
}
