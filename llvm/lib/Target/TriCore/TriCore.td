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

include "TriCoreRegisterInfo.td"
include "TriCoreInstrInfo.td"
include "TriCoreCallingConv.td"

def TriCoreInstrInfo : InstrInfo {
  let useDeprecatedPositionallyEncodedOperands = 1;
}

//===----------------------------------------------------------------------===//
// TriCore processors supported.
//===----------------------------------------------------------------------===//

class Proc<string Name, list<SubtargetFeature> Features>
    : Processor<Name, NoItineraries, Features>;

//===----------------------------------------------------------------------===//
// TriCore SubtargetFeature definitions.
//===----------------------------------------------------------------------===//

def FeatureFP  : SubtargetFeature<"fp",  "HasFP",    "true",
                                  "Enable IEEE 754 single-precision FPU">;
def FeatureDiv : SubtargetFeature<"div", "HasHWDiv", "true",
                                  "Enable hardware integer divide (DIV/MADD)">;
def FeatureDSP : SubtargetFeature<"dsp", "HasDSP",   "true",
                                  "Enable DSP extensions (MADD, MSUB, ...)">;

//===----------------------------------------------------------------------===//
// Processor definitions.
//===----------------------------------------------------------------------===//

def : Proc<"generic", []>;
def : Proc<"tc16",    []>;
def : Proc<"tc162",   [FeatureFP]>;
def : Proc<"tc18",    [FeatureFP, FeatureDiv]>;
def : Proc<"tc2x",    [FeatureFP, FeatureDiv, FeatureDSP]>;

//===----------------------------------------------------------------------===//
// Declare the target which we are implementing
//===----------------------------------------------------------------------===//

def TriCore : Target {
  let InstructionSet = TriCoreInstrInfo;
}
