//===--- TriCore.cpp - TriCore ToolChain Implementations -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TriCore.h"
#include "CommonArgs.h"
#include "clang/Driver/Driver.h"
#include "clang/Driver/Options.h"
#include "llvm/Option/ArgList.h"
#include "llvm/Support/Path.h"

using namespace clang;
using namespace clang::driver;
using namespace clang::driver::toolchains;
using namespace llvm::opt;

TriCoreToolChain::TriCoreToolChain(const Driver &D, const llvm::Triple &Triple,
                                   const ArgList &Args)
    : Generic_ELF(D, Triple, Args) {
  if (D.SysRoot.empty())
    return;

  SmallString<128> LibPath(D.SysRoot);
  llvm::sys::path::append(LibPath, "lib");
  tools::addPathIfExists(D, LibPath, getFilePaths());

  SmallString<128> TripleLibPath(D.SysRoot);
  llvm::sys::path::append(TripleLibPath, Triple.str(), "lib");
  tools::addPathIfExists(D, TripleLibPath, getFilePaths());
}

void TriCoreToolChain::AddClangSystemIncludeArgs(const ArgList &DriverArgs,
                                                 ArgStringList &CC1Args) const {
  if (DriverArgs.hasArg(options::OPT_nostdinc) ||
      DriverArgs.hasArg(options::OPT_nostdlibinc) ||
      getDriver().SysRoot.empty())
    return;

  SmallString<128> TripleInclude(getDriver().SysRoot);
  llvm::sys::path::append(TripleInclude, getTriple().str(), "include");
  addSystemInclude(DriverArgs, CC1Args, TripleInclude.str());

  SmallString<128> IncludeDir(getDriver().SysRoot);
  llvm::sys::path::append(IncludeDir, "include");
  addSystemInclude(DriverArgs, CC1Args, IncludeDir.str());
}

void TriCoreToolChain::addClangTargetOptions(const ArgList &DriverArgs,
                                             ArgStringList &CC1Args,
                                             Action::OffloadKind) const {
  if (const Arg *A = DriverArgs.getLastArg(options::OPT_mcpu_EQ)) {
    CC1Args.push_back("-target-cpu");
    CC1Args.push_back(DriverArgs.MakeArgString(A->getValue()));
  }
}