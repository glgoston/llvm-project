//=-- TriCoreMachineFuctionInfo.h - TriCore machine function info -*- C++ -*-=//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file declares TriCore-specific per-machine-function information.
//
//===----------------------------------------------------------------------===//

#ifndef TriCoreMACHINEFUNCTIONINFO_H
#define TriCoreMACHINEFUNCTIONINFO_H

#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"

namespace llvm {

// Forward declarations
class Function;

/// TriCoreFunctionInfo - This class is derived from MachineFunction private
/// TriCore target-specific information for each MachineFunction.
class TriCoreFunctionInfo : public MachineFunctionInfo {
  /// VarArgsFrameOffset — offset of the first variadic argument from the
  /// frame pointer (or stack pointer if no FP).  Set in LowerFormalArguments
  /// for vararg functions; used by LowerVASTART.
  int VarArgsFrameOffset = 0;

public:
  TriCoreFunctionInfo() {}

  ~TriCoreFunctionInfo() {}

  int getVarArgsFrameOffset() const { return VarArgsFrameOffset; }
  void setVarArgsFrameOffset(int Offset) { VarArgsFrameOffset = Offset; }
};
} // End llvm namespace

#endif // TriCoreMACHINEFUNCTIONINFO_H

