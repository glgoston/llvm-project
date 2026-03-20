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

#include "llvm/CodeGen/MachineFunction.h"

namespace llvm {

// Forward declarations
class Function;

/// TriCoreFunctionInfo - This class is derived from MachineFunction private
/// TriCore target-specific information for each MachineFunction.
class TriCoreFunctionInfo : public MachineFunctionInfo {
  /// Frame index of the first variadic argument save slot or first stack
  /// variadic argument.
  int VarArgsFrameIndex = 0;

public:
  TriCoreFunctionInfo() = default;
  explicit TriCoreFunctionInfo(const Function &F,
                               const TargetSubtargetInfo *STI) {}

  MachineFunctionInfo *
  clone(BumpPtrAllocator &Allocator, MachineFunction &DestMF,
        const DenseMap<MachineBasicBlock *, MachineBasicBlock *> &Src2DstMBB)
      const override {
    return DestMF.cloneInfo<TriCoreFunctionInfo>(*this);
  }

  ~TriCoreFunctionInfo() override = default;

  int getVarArgsFrameIndex() const { return VarArgsFrameIndex; }
  void setVarArgsFrameIndex(int Index) { VarArgsFrameIndex = Index; }
};
} // End llvm namespace

#endif // TriCoreMACHINEFUNCTIONINFO_H

