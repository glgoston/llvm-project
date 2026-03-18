//- TriCoreTargetObjectFile.cpp - Define TargetObjectFile for Tricore-*-C++-*-//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file declares the TriCore specific subclass of TargetMachine.
//
//===----------------------------------------------------------------------===//

#include "TriCoreTargetObjectFile.h"
#include "TriCoreSubtarget.h"
#include "TriCoreTargetMachine.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCSectionELF.h"
#include "llvm/Object/ELF.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Target/TargetMachine.h"
using namespace llvm;

static cl::opt<unsigned> SSThreshold(
    "tricore-ssection-threshold", cl::Hidden,
    cl::desc("Small data and bss section threshold size (default=8)"),
    cl::init(8));

void TriCoreTargetObjectFile::Initialize(MCContext &Ctx,
                                         const TargetMachine &TM) {
  TargetLoweringObjectFileELF::Initialize(Ctx, TM);

  SmallDataSection = getContext().getELFSection(
      ".sdata", ELF::SHT_PROGBITS, ELF::SHF_WRITE | ELF::SHF_ALLOC);

  SmallBSSSection = getContext().getELFSection(".sbss", ELF::SHT_NOBITS,
                                               ELF::SHF_WRITE | ELF::SHF_ALLOC);
}

// A address must be loaded from a small section if its size is less than the
// small section size threshold. Data in this section must be addressed using
// gp_rel operator.
bool TriCoreTargetObjectFile::isInSmallSection(uint64_t Size) const {
  return Size > 0 && Size <= SSThreshold;
}

// Return true if this global address should be placed into small data/bss
// section.
bool TriCoreTargetObjectFile::isGlobalInSmallSection(
    const GlobalObject *GO, const TargetMachine &TM) const {
  // Only global variables, not functions.
  const GlobalVariable *GVA = dyn_cast<GlobalVariable>(GO);
  if (!GVA)
    return false;

  // If the variable has an explicit section, it is placed in that section.
  if (GVA->hasSection()) {
    StringRef Section = GVA->getSection();

    // Explicitly placing any variable in the small data section overrides
    // the global -G value.
    if (Section == ".sdata" || Section == ".sbss")
      return true;

    // Otherwise reject putting the variable to small section if it has an
    // explicit section name.
    return false;
  }

  if (((GVA->hasExternalLinkage() && GVA->isDeclaration()) ||
       GVA->hasCommonLinkage()))
    return false;

  Type *Ty = GVA->getValueType();
  // It is possible that the type of the global is unsized, i.e. a declaration
  // of a extern struct. In this case don't presume it is in the small data
  // section. This happens e.g. when building the FreeBSD kernel.
  if (!Ty->isSized())
    return false;

  return isInSmallSection(
      GVA->getParent()->getDataLayout().getTypeAllocSize(Ty));
}

MCSection *TriCoreTargetObjectFile::SelectSectionForGlobal(
    const GlobalObject *GO, SectionKind Kind, const TargetMachine &TM) const {
  // TODO: Could also support "weak" symbols as well with ".gnu.linkonce.s.*"
  // sections?

  // Handle Small Section classification here.
  if (Kind.isBSS() && isGlobalInSmallSection(GO, TM))
    return SmallBSSSection;
  if (Kind.isData() && isGlobalInSmallSection(GO, TM))
    return SmallDataSection;

  // Otherwise, we work the same as ELF.
  return TargetLoweringObjectFileELF::SelectSectionForGlobal(GO, Kind, TM);
}
