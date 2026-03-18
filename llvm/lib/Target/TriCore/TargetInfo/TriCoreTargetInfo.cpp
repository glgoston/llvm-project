//===-- TriCoreTargetInfo.cpp - TriCore Target Implementation -------------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

//#include "TriCore.h"
//#include "llvm/IR/Module.h"
// #include "llvm/Support/TargetRegistry.h"
#include "TriCoreTargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
using namespace llvm;

Target &llvm::getTheTriCoreTarget() {
  static Target TheTriCoreTarget;
  return TheTriCoreTarget;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeTriCoreTargetInfo() {
  RegisterTarget<Triple::tricore> X(llvm::getTheTriCoreTarget(), "tricore", "TriCore", "tricore");
}
