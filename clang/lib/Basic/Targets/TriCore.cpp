//===--- TriCore.cpp - Implement TriCore target feature support ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TriCore.h"
#include "clang/Basic/MacroBuilder.h"

using namespace clang;
using namespace clang::targets;

void TriCoreTargetInfo::getTargetDefines(const LangOptions &Opts,
                                         MacroBuilder &Builder) const {
  (void)Opts;
  Builder.defineMacro("__tricore__");
  Builder.defineMacro("__TRICORE__");
  Builder.defineMacro("__ELF__");

  StringRef CPU = getTargetOpts().CPU;
  if (CPU == "tc16")
    Builder.defineMacro("__TC16__");
  else if (CPU == "tc162")
    Builder.defineMacro("__TC162__");
  else if (CPU == "tc18")
    Builder.defineMacro("__TC18__");
  else if (CPU == "tc2x")
    Builder.defineMacro("__TC2X__");
}

bool TriCoreTargetInfo::isValidCPUName(StringRef Name) const {
  return Name == "generic" || Name == "tc16" || Name == "tc162" ||
         Name == "tc18" || Name == "tc2x";
}

void TriCoreTargetInfo::fillValidCPUList(
    SmallVectorImpl<StringRef> &Values) const {
  Values.push_back("generic");
  Values.push_back("tc16");
  Values.push_back("tc162");
  Values.push_back("tc18");
  Values.push_back("tc2x");
}

bool TriCoreTargetInfo::setCPU(const std::string &Name) {
  if (!isValidCPUName(Name))
    return false;

  CPU = Name;
  return true;
}
