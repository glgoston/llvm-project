//===--- TriCore.h - Declare TriCore target feature support ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_CLANG_LIB_BASIC_TARGETS_TRICORE_H
#define LLVM_CLANG_LIB_BASIC_TARGETS_TRICORE_H

#include "clang/Basic/TargetInfo.h"
#include "clang/Basic/TargetOptions.h"
#include "llvm/ADT/Triple.h"
#include "llvm/Support/Compiler.h"

namespace clang {
namespace targets {

class LLVM_LIBRARY_VISIBILITY TriCoreTargetInfo : public TargetInfo {
  std::string CPU = "generic";

public:
  TriCoreTargetInfo(const llvm::Triple &Triple, const TargetOptions &)
      : TargetInfo(Triple) {
    resetDataLayout("e-m:e-p:32:32-i64:32-a:0:32-n32");

    IntWidth = IntAlign = 32;
    LongWidth = LongAlign = 32;
    LongLongWidth = LongLongAlign = 64;
    PointerWidth = PointerAlign = 32;
    SuitableAlign = 32;

    SizeType = UnsignedInt;
    PtrDiffType = SignedInt;
    IntPtrType = SignedInt;
    IntMaxType = SignedLongLong;
    SigAtomicType = SignedInt;

    TLSSupported = false;
  }

  void getTargetDefines(const LangOptions &Opts,
                        MacroBuilder &Builder) const override;

  bool hasFeature(StringRef Feature) const override {
    return Feature == "tricore";
  }

  bool isValidCPUName(StringRef Name) const override;

  void fillValidCPUList(SmallVectorImpl<StringRef> &Values) const override;

  bool setCPU(const std::string &Name) override;

  ArrayRef<const char *> getGCCRegNames() const override {
    // Basic register name set for inline asm validation.
    static const char *const GCCRegNames[] = {
        "d0",  "d1",  "d2",  "d3",  "d4",  "d5",  "d6",  "d7",
        "d8",  "d9",  "d10", "d11", "d12", "d13", "d14", "d15",
        "a0",  "a1",  "a2",  "a3",  "a4",  "a5",  "a6",  "a7",
        "a8",  "a9",  "a10", "a11", "a12", "a13", "a14", "a15",
        "sp",  "pc",  "psw", "pcxi",
    };
    return llvm::ArrayRef(GCCRegNames);
  }

  ArrayRef<TargetInfo::GCCRegAlias> getGCCRegAliases() const override {
    return std::nullopt;
  }

  bool validateAsmConstraint(const char *&Name,
                             TargetInfo::ConstraintInfo &Info) const override {
    switch (*Name) {
    case 'd': // Data register
    case 'a': // Address register
    case 'e': // Extended register (E-regs, 64-bit)
    case 'r': // Generic register (defaults to data register)
      Info.setAllowsRegister();
      return true;
    default:
      return false;
    }
  }

  const char *getClobbers() const override { return ""; }

  BuiltinVaListKind getBuiltinVaListKind() const override {
    return TargetInfo::VoidPtrBuiltinVaList;
  }

  ArrayRef<Builtin::Info> getTargetBuiltins() const override {
    return std::nullopt;
  }

  bool hasBitIntType() const override { return true; }
};

} // namespace targets
} // namespace clang

#endif // LLVM_CLANG_LIB_BASIC_TARGETS_TRICORE_H
