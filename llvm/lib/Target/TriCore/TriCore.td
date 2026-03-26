//===-- TriCore.td - Describe the TriCore Target Machine -------*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This is the top level entry point for the TriCore target.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Target-independent interfaces which we are implementing
//===----------------------------------------------------------------------===//

include "llvm/Target/Target.td"

//===----------------------------------------------------------------------===//
// Descriptions
//===----------------------------------------------------------------------===//

include "TriCoreSchedule.td"
include "TriCoreRegisterInfo.td"
include "TriCoreInstrInfo.td"
include "TriCoreCallingConv.td"

def TriCoreInstrInfo : InstrInfo {
  let useDeprecatedPositionallyEncodedOperands = 1;
}

//===----------------------------------------------------------------------===//
// TriCore processors supported.
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// SubtargetFeature definitions.
//===----------------------------------------------------------------------===//

def FeatureFP  : SubtargetFeature<"fp",  "HasFP",    "true",
                                  "Enable IEEE 754 single-precision FPU (tc162+)">;
def FeatureDiv : SubtargetFeature<"div", "HasHWDiv", "true",
                                  "Enable hardware integer divide (DIV/DIV.U) (tc18+)">;
// MADD, MSUB, ADDS, SUBS, ABSS, etc. are *standard* TC1.6P instructions
// (listed under base Integer Arithmetic in the TC1.6P ISA manual), not
// optional DSP extensions.  This feature marks tc2x-and-newer, where the
// full TC1.6P / AURIX TC2xx baseline instruction set is available.
def FeatureMAC : SubtargetFeature<"mac", "HasMAC",   "true",
                                  "Enable TC1.6P baseline MAC and saturating-arithmetic "
                                  "(MADD, MSUB, ADDS, SUBS, ABSS, ...) (tc2x+)">;

//===----------------------------------------------------------------------===//
// Processor definitions.
//===----------------------------------------------------------------------===//

def : ProcessorModel<"generic", TriCoreSchedModel, []>;
def : ProcessorModel<"tc16",    TriCoreSchedModel, []>;
def : ProcessorModel<"tc162",   TriCoreSchedModel, [FeatureFP]>;
def : ProcessorModel<"tc18",    TriCoreSchedModel, [FeatureFP, FeatureDiv]>;
def : ProcessorModel<"tc2x",    TriCoreSchedModel, [FeatureFP, FeatureDiv, FeatureMAC]>;

//===----------------------------------------------------------------------===//
// Declare the target which we are implementing
//===----------------------------------------------------------------------===//

def TriCore : Target {
  let InstructionSet = TriCoreInstrInfo;
}
