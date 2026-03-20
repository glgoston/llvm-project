//===-- TriCoreISelLowering.cpp - TriCore DAG Lowering Implementation -----===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file implements the TriCoreTargetLowering class.
//
//===----------------------------------------------------------------------===//

#include "TriCoreISelLowering.h"
#include "TriCore.h"
#include "TriCoreMachineFunctionInfo.h"
#include "TriCoreSubtarget.h"
#include "TriCoreTargetMachine.h"
#include "llvm/CodeGen/CallingConvLower.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineJumpTableInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/ValueTypes.h"
#include "llvm/IR/CallingConv.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/GlobalAlias.h"
#include "llvm/IR/GlobalVariable.h"
#include "llvm/IR/Intrinsics.h"
#include "llvm/Support/Debug.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

const char *TriCoreTargetLowering::getTargetNodeName(unsigned Opcode) const {
  switch (Opcode) {
  default:
    return nullptr;
  case TriCoreISD::RET_FLAG:
    return "TriCoreISD::RetFlag";
  case TriCoreISD::LOAD_SYM:
    return "TriCoreISD::LOAD_SYM";
  case TriCoreISD::MOVEi32:
    return "TriCoreISD::MOVEi32";
  case TriCoreISD::CALL:
    return "TriCoreISD::CALL";
  case TriCoreISD::BR_CC:
    return "TriCoreISD::BR_CC";
  case TriCoreISD::SELECT_CC:
    return "TriCoreISD::SELECT_CC";
  case TriCoreISD::LOGICCMP:
    return "TriCoreISD::LOGICCMP";
  case TriCoreISD::CMP:
    return "TriCoreISD::CMP";
  case TriCoreISD::IMASK:
    return "TriCoreISD::IMASK";
  case TriCoreISD::Wrapper:
    return "TriCoreISD::Wrapper";
  case TriCoreISD::SH:
    return "TriCoreISD::SH";
  case TriCoreISD::SHA:
    return "TriCoreISD::SHA";
  case TriCoreISD::EXTR:
    return "TriCoreISD::EXTR";
  }
}

TriCoreTargetLowering::TriCoreTargetLowering(TriCoreTargetMachine &TriCoreTM)
    : TargetLowering(TriCoreTM), Subtarget(*TriCoreTM.getSubtargetImpl()) {
  // Set up the register classes.
  addRegisterClass(MVT::i32, &TriCore::DataRegsRegClass);
  // addRegisterClass(MVT::i32, &TriCore::AddrRegsRegClass);
  addRegisterClass(MVT::i64, &TriCore::ExtRegsRegClass);
  // addRegisterClass(MVT::i32, &TriCore::PSRegsRegClass);

  // Compute derived properties from the register classes
  computeRegisterProperties(Subtarget.getRegisterInfo());

  setStackPointerRegisterToSaveRestore(TriCore::A10);

  setSchedulingPreference(Sched::Source);

  //  for (MVT VT : MVT::integer_valuetypes()) {
  //     setLoadExtAction(ISD::SEXTLOAD, VT, MVT::i8,  Expand);
  //     setLoadExtAction(ISD::SEXTLOAD, MVT::i32, MVT::i16,  Promote);
  //  		 setLoadExtAction(ISD::SEXTLOAD, VT, MVT::i32, Expand);
  //   }

  // Nodes that require custom lowering
  setOperationAction(ISD::GlobalAddress, MVT::i32, Custom);
  setOperationAction(ISD::BR_CC, MVT::i32, Custom);
  setOperationAction(ISD::BR_CC, MVT::i64, Custom);
  setOperationAction(ISD::SELECT_CC, MVT::i32, Custom);
  setOperationAction(ISD::SETCC, MVT::i32, Custom);
  setOperationAction(ISD::SHL, MVT::i32, Custom);
  setOperationAction(ISD::SRL, MVT::i32, Custom);
  setOperationAction(ISD::SRA, MVT::i32, Custom);
  // setOperationAction(ISD::SRA,           MVT::i16,   Custom);
  // setOperationAction(ISD::SIGN_EXTEND,   MVT::i16,   Expand);

  // Integer division has no hardware support; expand to runtime library calls.
  setOperationAction(ISD::SDIV, MVT::i32, Expand);
  setOperationAction(ISD::UDIV, MVT::i32, Expand);
  setOperationAction(ISD::SREM, MVT::i32, Expand);
  setOperationAction(ISD::UREM, MVT::i32, Expand);

  // Enable jump tables for switch statements with >= 4 cases.
  setMinimumJumpTableEntries(4);

  // Varargs: VASTART needs custom lowering so we can record the vararg area.
  setOperationAction(ISD::VASTART, MVT::Other, Custom);
  // VAARG/VACOPY/VAEND use the standard expansion.
  setOperationAction(ISD::VAARG,   MVT::Other, Expand);
  setOperationAction(ISD::VACOPY,  MVT::Other, Expand);
  setOperationAction(ISD::VAEND,   MVT::Other, Expand);

  // for (MVT VT : MVT::integer_valuetypes())
  // setOperationAction(ISD::SIGN_EXTEND_INREG, MVT::i16,   Custom);
}

SDValue TriCoreTargetLowering::LowerOperation(SDValue Op,
                                              SelectionDAG &DAG) const {
  switch (Op.getOpcode()) {
  default:
    llvm_unreachable("Unimplemented operand");
  case ISD::GlobalAddress:
    return LowerGlobalAddress(Op, DAG);
  case ISD::BR_CC:
    return LowerBR_CC(Op, DAG);
  case ISD::SELECT_CC:
    return LowerSELECT_CC(Op, DAG);
  case ISD::SETCC:
    return LowerSETCC(Op, DAG);
  case ISD::SHL:
  case ISD::SRL:
  case ISD::SRA:
    return LowerShifts(Op, DAG);
  case ISD::VASTART:
    return LowerVASTART(Op, DAG);
    // case ISD::SIGN_EXTEND:      	return LowerSIGN_EXTEND(Op, DAG);
    // case ISD::SIGN_EXTEND_INREG:  return LowerSIGN_EXTEND_INREG(Op, DAG);
  }
}

SDValue TriCoreTargetLowering::LowerShifts(SDValue Op,
                                           SelectionDAG &DAG) const {
  unsigned Opc = Op.getOpcode();
  SDNode *N = Op.getNode();
  SDValue shiftValue = N->getOperand(1);

  EVT VT = Op.getValueType();
  SDLoc dl(N);
  switch (Opc) {
  default:
    llvm_unreachable("Invalid shift opcode!");
  case ISD::SHL:
    return DAG.getNode(TriCoreISD::SH, dl, VT, N->getOperand(0),
                       N->getOperand(1));
  case ISD::SRL:
  case ISD::SRA:
    if (isa<ConstantSDNode>(shiftValue)) {
      int64_t shiftSVal = cast<ConstantSDNode>(shiftValue)->getSExtValue();
      assert((shiftSVal >= -32 && shiftSVal < 32) &&
             "Shift can only be between -32 and +31");
      ConstantSDNode *shiftSD = cast<ConstantSDNode>(N->getOperand(1));
      uint64_t shiftVal = -shiftSD->getZExtValue();
      SDValue negShift = DAG.getConstant(shiftVal, dl, MVT::i32);

      unsigned Opcode = (Opc == ISD::SRL) ? TriCoreISD::SH : TriCoreISD::SHA;

      return DAG.getNode(Opcode, dl, VT, N->getOperand(0), negShift);
    } else { // shift value is stored in a register

      SDValue regOP = N->getOperand(1);
      // Create subtraction node
      SDValue zero = DAG.getConstant(0, dl, MVT::i32);
      SDValue rsubNode = DAG.getNode(ISD::SUB, dl, MVT::i32, zero, regOP);
      unsigned Opcode = (Opc == ISD::SRL) ? TriCoreISD::SH : TriCoreISD::SHA;
      return DAG.getNode(Opcode, dl, MVT::i32, N->getOperand(0), rsubNode);
    }
  }
}

static SDValue EmitCMP(SDValue &LHS, SDValue &RHS, ISD::CondCode CC, SDLoc dl,
                       SelectionDAG &DAG, SDValue &tricoreCC) {
  // FIXME: Handle bittests someday
  assert(!LHS.getValueType().isFloatingPoint() && "We don't handle FP yet");

  EVT VT = LHS.getValueType();
  // FIXME: Handle jump negative someday
  SDValue TargetCC;
  TriCoreCC::CondCodes TCC = TriCoreCC::COND_INVALID;

  // outs() << "CC: " << (int)CC << "\n";

  switch (CC) {
  default:
    llvm_unreachable("Invalid integer condition!");
  case ISD::SETEQ:
    TCC = TriCoreCC::COND_EQ; // aka COND_Z
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    // Minor optimization: if LHS is a constant, swap operands, then the
    // constant can be folded into comparison.
    if (LHS.getOpcode() == ISD::Constant)
      std::swap(LHS, RHS);
    break;
  case ISD::SETNE:
    TCC = TriCoreCC::COND_NE; // aka COND_NZ
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    // Minor optimization: if LHS is a constant, swap operands, then the
    // constant can be folded into comparison.
    if (LHS.getOpcode() == ISD::Constant)
      std::swap(LHS, RHS);
    break;
  case ISD::SETULE:
    std::swap(LHS, RHS); // FALLTHROUGH
  case ISD::SETUGE:
    // Turn lhs u>= rhs with lhs constant into rhs u< lhs+1, this allows us to
    // fold constant into instruction.
    if (const ConstantSDNode *C = dyn_cast<ConstantSDNode>(LHS)) {
      LHS = RHS;
      RHS = DAG.getConstant(C->getSExtValue() + 1, dl, C->getValueType(0));
      TCC = TriCoreCC::COND_LT;
      break;
    }
    TCC = TriCoreCC::COND_GE; // aka COND_C
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    break;
  case ISD::SETUGT:
    std::swap(LHS, RHS); // FALLTHROUGH
  case ISD::SETULT:
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    // Turn lhs u< rhs with lhs constant into rhs u>= lhs+1, this allows us to
    // fold constant into instruction.
    if (const ConstantSDNode *C = dyn_cast<ConstantSDNode>(LHS)) {
      LHS = RHS;
      RHS = DAG.getConstant(C->getSExtValue() + 1, dl, C->getValueType(0));
      TCC = TriCoreCC::COND_GE;
      break;
    }
    TCC = TriCoreCC::COND_LT; // aka COND_NC
    break;
  case ISD::SETLE:
    std::swap(LHS, RHS); // FALLTHROUGH
  case ISD::SETGE:
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    // Turn lhs >= rhs with lhs constant into rhs < lhs+1, this allows us to
    // fold constant into instruction.
    if (const ConstantSDNode *C = dyn_cast<ConstantSDNode>(LHS)) {
      LHS = RHS;
      RHS = DAG.getConstant(C->getSExtValue() + 1, dl, C->getValueType(0));
      TCC = TriCoreCC::COND_LT;
      break;
    }
    TCC = TriCoreCC::COND_GE;
    break;
  case ISD::SETGT:
    std::swap(LHS, RHS); // FALLTHROUGH
  case ISD::SETLT:
    tricoreCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);
    // Turn lhs < rhs with lhs constant into rhs >= lhs+1, this allows us to
    // fold constant into instruction.
    if (const ConstantSDNode *C = dyn_cast<ConstantSDNode>(LHS)) {
      LHS = RHS;
      RHS = DAG.getConstant(C->getSExtValue() + 1, dl, C->getValueType(0));
      TCC = TriCoreCC::COND_GE;
      break;
    }
    TCC = TriCoreCC::COND_LT;
    break;
  }

  if (VT == MVT::i64) {

    SDValue LHSlo = DAG.getNode(ISD::EXTRACT_ELEMENT, dl, MVT::i32, LHS,
                                DAG.getIntPtrConstant(0, dl));
    SDValue LHShi = DAG.getNode(ISD::EXTRACT_ELEMENT, dl, MVT::i32, LHS,
                                DAG.getIntPtrConstant(1, dl));

    SDValue RHSlo, RHShi;
    if (RHS.getOpcode() != ISD::Constant) {
      RHSlo = DAG.getNode(ISD::EXTRACT_ELEMENT, dl, MVT::i32, RHS,
                          DAG.getIntPtrConstant(0, dl));
      RHShi = DAG.getNode(ISD::EXTRACT_ELEMENT, dl, MVT::i32, RHS,
                          DAG.getIntPtrConstant(1, dl));
    } else {
      ConstantSDNode *C = cast<ConstantSDNode>(RHS);
      int64_t immVal = C->getSExtValue();
      int32_t lowerByte = immVal & 0xffffffff;
      int32_t HigherByte = (immVal >> 32);

      RHSlo = DAG.getConstant(lowerByte, dl, MVT::i32);
      RHShi = DAG.getConstant(HigherByte, dl, MVT::i32);
      // RHShi.dump();
    }

    SDValue TargetEQ;
    if (TCC != TriCoreCC::COND_NE)
      TargetEQ = DAG.getConstant(TriCoreCC::COND_EQ, dl, MVT::i32);
    else
      TargetEQ = DAG.getConstant(TCC, dl, MVT::i32);

    SDVTList VTs = DAG.getVTList(MVT::i32, MVT::Glue);
    SDValue Ops[] = {LHShi, RHShi, TargetEQ};
    SDValue compareHi = DAG.getNode(TriCoreISD::CMP, dl, VTs, Ops);

    TargetCC = DAG.getConstant(TCC, dl, MVT::i32);
    SDValue Ops2[] = {compareHi.getValue(0), LHSlo, RHSlo, TargetCC,
                      compareHi.getValue(1)};
    SDValue compareLo = DAG.getNode(TriCoreISD::LOGICCMP, dl, VTs, Ops2);

    if ((TCC == TriCoreCC::COND_NE) || (TCC == TriCoreCC::COND_EQ))
      return compareLo;

    SDValue SecondCC = DAG.getConstant(TriCoreCC::COND_LT + 10, dl, MVT::i32);
    if (RHS.getOpcode() == ISD::Constant) {
      std::swap(LHShi, RHShi);
      SecondCC = DAG.getConstant(TCC + 10, dl, MVT::i32);
    }

    SDValue Ops3[] = {compareLo.getValue(0), RHShi, LHShi, SecondCC,
                      compareLo.getValue(1)};
    SDValue compareCombine = DAG.getNode(TriCoreISD::LOGICCMP, dl, VTs, Ops3);

    return compareCombine;
    // LHS2.dump();
  }

  TargetCC = DAG.getConstant(TCC, dl, MVT::i32);
  SDVTList VTs = DAG.getVTList(MVT::i32, MVT::Glue);
  SDValue Ops[] = {LHS, RHS, TargetCC};

  //  return DAG.getNode(TriCoreISD::CMP, dl, MVT::i32, LHS, RHS, TargetCC);

  return DAG.getNode(TriCoreISD::CMP, dl, VTs, Ops);
}

SDValue TriCoreTargetLowering::LowerBR_CC(SDValue Op, SelectionDAG &DAG) const {
  SDValue Chain = Op.getOperand(0);
  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(1))->get();
  SDValue LHS = Op.getOperand(2);
  SDValue RHS = Op.getOperand(3);
  SDValue Dest = Op.getOperand(4);
  SDLoc dl(Op);

  SDValue tricoreCC;
  SDValue Flag = EmitCMP(LHS, RHS, CC, dl, DAG, tricoreCC);

  // TriCore comparison nodes materialize a boolean-like value in a data
  // register. Branch-on-true is therefore always "nonzero" regardless of the
  // original IR condition code.
  SDValue BranchOnTrueCC = DAG.getConstant(TriCoreCC::COND_NE, dl, MVT::i32);

  // Flag.getValue(1).dump();

  return DAG.getNode(TriCoreISD::BR_CC, dl, Op.getValueType(), Chain, Dest,
                     Flag.getValue(0), BranchOnTrueCC, Flag.getValue(1));
}

SDValue TriCoreTargetLowering::LowerSETCC(SDValue Op, SelectionDAG &DAG) const {
  SDValue LHS = Op.getOperand(0);
  SDValue RHS = Op.getOperand(1);
  SDLoc dl(Op);

  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(2))->get();
  SDValue TargetCC;
  SDValue Flag = EmitCMP(LHS, RHS, CC, dl, DAG, TargetCC);
  SDValue One  = DAG.getConstant(1, dl, Op.getValueType());
  SDValue Zero = DAG.getConstant(0, dl, Op.getValueType());
  SDVTList VTs = DAG.getVTList(Op.getValueType(), MVT::Glue);
  SDValue Ops[] = {One, Zero, TargetCC, Flag};

  return DAG.getNode(TriCoreISD::SELECT_CC, dl, VTs, Ops);
}

SDValue TriCoreTargetLowering::LowerSELECT_CC(SDValue Op,
                                              SelectionDAG &DAG) const {
  SDValue LHS = Op.getOperand(0);
  SDValue RHS = Op.getOperand(1);
  SDValue TrueV = Op.getOperand(2);
  SDValue FalseV = Op.getOperand(3);
  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(4))->get();
  SDLoc dl(Op);

  SDValue tricoreCC;
  SDValue Flag = EmitCMP(LHS, RHS, CC, dl, DAG, tricoreCC);

  SDVTList VTs = DAG.getVTList(Op.getValueType(), MVT::Glue);
  SDValue Ops[] = {TrueV, FalseV, tricoreCC, Flag};

  return DAG.getNode(TriCoreISD::SELECT_CC, dl, VTs, Ops);
}

SDValue TriCoreTargetLowering::LowerGlobalAddress(SDValue Op,
                                                  SelectionDAG &DAG) const {

  EVT VT = Op.getValueType();

  GlobalAddressSDNode *GlobalAddr = cast<GlobalAddressSDNode>(Op.getNode());
  int64_t Offset = cast<GlobalAddressSDNode>(Op)->getOffset();
  SDValue TargetAddr =
      DAG.getTargetGlobalAddress(GlobalAddr->getGlobal(), Op, MVT::i32, Offset);
  return DAG.getNode(TriCoreISD::Wrapper, Op, VT, TargetAddr);

  //  EVT VT = Op.getValueType();
  //  GlobalAddressSDNode *GlobalAddr = cast<GlobalAddressSDNode>(Op.getNode());
  //  SDValue TargetAddr =
  //      DAG.getTargetGlobalAddress(GlobalAddr->getGlobal(), Op, MVT::i32);
  //  return DAG.getNode(TriCoreISD::Wrapper, Op, VT, TargetAddr);
}

SDValue TriCoreTargetLowering::LowerVASTART(SDValue Op,
                                             SelectionDAG &DAG) const {
  MachineFunction &MF = DAG.getMachineFunction();
  TriCoreFunctionInfo *FuncInfo = MF.getInfo<TriCoreFunctionInfo>();
  SDLoc dl(Op);

  // va_start stores a pointer to the first variadic argument into the
  // va_list object.  Frame pointer + VarArgsFrameOffset gives that address.
  SDValue FI = DAG.getFrameIndex(FuncInfo->getVarArgsFrameOffset(),
                                  getPointerTy(DAG.getDataLayout()));
  const Value *SV = cast<SrcValueSDNode>(Op.getOperand(2))->getValue();
  return DAG.getStore(Op.getOperand(0), dl, FI, Op.getOperand(1),
                      MachinePointerInfo(SV));
}

std::pair<unsigned, const TargetRegisterClass *>
TriCoreTargetLowering::getRegForInlineAsmConstraint(
    const TargetRegisterInfo *TRI, StringRef Constraint, MVT VT) const {
  if (Constraint.size() == 1) {
    switch (Constraint[0]) {
    case 'd': return std::make_pair(0U, &TriCore::DataRegsRegClass);
    case 'a': return std::make_pair(0U, &TriCore::AddrRegsRegClass);
    case 'e': return std::make_pair(0U, &TriCore::ExtRegsRegClass);
    case 'r': return std::make_pair(0U, &TriCore::DataRegsRegClass);
    }
  }
  return TargetLowering::getRegForInlineAsmConstraint(TRI, Constraint, VT);
}

MachineBasicBlock *TriCoreTargetLowering::EmitInstrWithCustomInserter(
    MachineInstr &MI, MachineBasicBlock *BB) const {
  unsigned Opc = MI.getOpcode();

  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  DebugLoc dl = MI.getDebugLoc();

  assert(Opc == TriCore::Select8 && "Unexpected instr type to insert");
  // To "insert" a SELECT instruction, we actually have to insert the diamond
  // control-flow pattern.  The incoming instruction knows the destination vreg
  // to set, the condition code register to branch on, the true/false values to
  // select between, and a branch opcode to use.
  const BasicBlock *LLVM_BB = BB->getBasicBlock();
  MachineFunction::iterator I = BB->getIterator();
  ++I;

  //  thisMBB:
  //  ...
  //   TrueVal = ...
  //   cmpTY ccX, r1, r2
  //   jCC copy1MBB
  //   fallthrough --> copy0MBB
  MachineBasicBlock *thisMBB = BB;
  MachineFunction *F = BB->getParent();
  MachineBasicBlock *copy0MBB = F->CreateMachineBasicBlock(LLVM_BB);
  MachineBasicBlock *copy1MBB = F->CreateMachineBasicBlock(LLVM_BB);
  F->insert(I, copy0MBB);
  F->insert(I, copy1MBB);
  // Update machine-CFG edges by transferring all successors of the current
  // block to the new block which will contain the Phi node for the select.
  copy1MBB->splice(copy1MBB->begin(), BB,
                   std::next(MachineBasicBlock::iterator(MI)), BB->end());
  copy1MBB->transferSuccessorsAndUpdatePHIs(BB);
  // Next, add the true and fallthrough blocks as its successors.
  BB->addSuccessor(copy0MBB);
  BB->addSuccessor(copy1MBB);

  // MI.dump();

  BuildMI(BB, dl, TII.get(TriCore::JNZsbr))
      .addMBB(copy1MBB)
      .addReg(MI.getOperand(4).getReg());

  //  copy0MBB:
  //   %FalseValue = ...
  //   # fallthrough to copy1MBB
  BB = copy0MBB;

  // Update machine-CFG edges
  BB->addSuccessor(copy1MBB);

  //  copy1MBB:
  //   %Result = phi [ %FalseValue, copy0MBB ], [ %TrueValue, thisMBB ]
  //  ...
  BB = copy1MBB;
  BuildMI(*BB, BB->begin(), dl, TII.get(TriCore::PHI),
          MI.getOperand(0).getReg())
      .addReg(MI.getOperand(2).getReg())
      .addMBB(copy0MBB)
      .addReg(MI.getOperand(1).getReg())
      .addMBB(thisMBB);

  MI.eraseFromParent(); // The pseudo instruction is gone now.
  return BB;
}

//===----------------------------------------------------------------------===//
//                      Calling Convention Implementation
//===----------------------------------------------------------------------===//

#include "TriCoreGenCallingConv.inc"

/// TriCore call implementation
SDValue
TriCoreTargetLowering::LowerCall(TargetLowering::CallLoweringInfo &CLI,
                                 SmallVectorImpl<SDValue> &InVals) const {
  SelectionDAG &DAG = CLI.DAG;
  SDLoc &Loc = CLI.DL;
  SmallVectorImpl<ISD::OutputArg> &Outs = CLI.Outs;
  SmallVectorImpl<SDValue> &OutVals = CLI.OutVals;
  SmallVectorImpl<ISD::InputArg> &Ins = CLI.Ins;
  SDValue Chain = CLI.Chain;
  SDValue Callee = CLI.Callee;
  CallingConv::ID CallConv = CLI.CallConv;
  const bool isVarArg = CLI.IsVarArg;

  CLI.IsTailCall = false;

  if (isVarArg)
    llvm_unreachable("Unimplemented");

  // Analyze operands of the call, assigning locations to each operand.
  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CallConv, isVarArg, DAG.getMachineFunction(), ArgLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeCallOperands(Outs, CC_TriCore);

  // Get the size of the outgoing arguments stack space requirement.
  const unsigned NumBytes = CCInfo.getNextStackOffset();

  Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, Loc);

  SmallVector<std::pair<unsigned, SDValue>, 8> RegsToPass;
  SmallVector<SDValue, 8> MemOpChains;

  // Lower the callee address.  CC_TriCore already routed each argument to the
  // correct register class (A4-A7 for pointer args, E4/E6 for i64, D4-D7 for
  // i32) via CCIfPtr, so no manual fixup is needed.
  if (GlobalAddressSDNode *G = dyn_cast<GlobalAddressSDNode>(Callee))
    Callee = DAG.getTargetGlobalAddress(G->getGlobal(), Loc, MVT::i32);
  else if (ExternalSymbolSDNode *ES = dyn_cast<ExternalSymbolSDNode>(Callee))
    Callee = DAG.getTargetExternalSymbol(ES->getSymbol(), MVT::i32);
  // else: indirect call via address register — Callee is already correct.

  // Walk the register/memloc assignments, inserting copies/loads.
  for (unsigned i = 0, e = ArgLocs.size(); i != e; ++i) {
    CCValAssign &VA = ArgLocs[i];
    SDValue Arg = OutVals[i];

    // We only handle fully promoted arguments.
    assert(VA.getLocInfo() == CCValAssign::Full && "Unhandled loc info");

    if (VA.isRegLoc()) {
      RegsToPass.push_back(std::make_pair(VA.getLocReg(), Arg));
      continue;
    }
    assert(VA.isMemLoc() &&
           "Only support passing arguments through registers or via the stack");

    SDValue StackPtr = DAG.getRegister(TriCore::A10, MVT::i32);
    SDValue PtrOff = DAG.getIntPtrConstant(VA.getLocMemOffset(), Loc);
    PtrOff = DAG.getNode(ISD::ADD, Loc, MVT::i32, StackPtr, PtrOff);
    MemOpChains.push_back(
        DAG.getStore(Chain, Loc, Arg, PtrOff, MachinePointerInfo()));
  }

  // Emit all stores, make sure they occur before the call.
  if (!MemOpChains.empty())
    Chain = DAG.getNode(ISD::TokenFactor, Loc, MVT::Other, MemOpChains);

  // Build a sequence of copy-to-reg nodes chained together with token chain
  // and flag operands which copy the outgoing args into the appropriate regs.
  SDValue InFlag;
  for (auto &Reg : RegsToPass) {
    Chain = DAG.getCopyToReg(Chain, Loc, Reg.first, Reg.second, InFlag);
    InFlag = Chain.getValue(1);
  }

  std::vector<SDValue> Ops;
  Ops.push_back(Chain);
  Ops.push_back(Callee);

  // Add argument registers to the end of the list so that they are known live
  // into the call.
  for (auto &Reg : RegsToPass)
    Ops.push_back(DAG.getRegister(Reg.first, Reg.second.getValueType()));

  // Add a register mask operand representing the call-preserved registers.
  const TargetRegisterInfo *TRI = DAG.getSubtarget().getRegisterInfo();
  const uint32_t *Mask =
      TRI->getCallPreservedMask(DAG.getMachineFunction(), CallConv);
  assert(Mask && "Missing call preserved mask for calling convention");
  Ops.push_back(DAG.getRegisterMask(Mask));

  if (InFlag.getNode())
    Ops.push_back(InFlag);

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);

  // Returns a chain and a flag for retval copy to use.
  Chain = DAG.getNode(TriCoreISD::CALL, Loc, NodeTys, Ops);
  InFlag = Chain.getValue(1);

  Chain = DAG.getCALLSEQ_END(Chain, DAG.getIntPtrConstant(NumBytes, Loc, true),
                             DAG.getIntPtrConstant(0, Loc, true), InFlag, Loc);
  if (!Ins.empty())
    InFlag = Chain.getValue(1);

  // Handle result values, copying them out of physregs into vregs that we
  // return.
  return LowerCallResult(Chain, InFlag, CallConv, isVarArg, Ins, Loc, DAG,
                         InVals);
}

SDValue TriCoreTargetLowering::LowerCallResult(
    SDValue Chain, SDValue InGlue, CallingConv::ID CallConv, bool isVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, SDLoc dl, SelectionDAG &DAG,
    SmallVectorImpl<SDValue> &InVals) const {
  // Assign locations to each value returned by this call.
  // RetCC_TriCore already handles pointer returns via CCIfPtr → A2, so no
  // manual override is needed.
  SmallVector<CCValAssign, 16> RVLocs;
  CCState CCInfo(CallConv, isVarArg, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeCallResult(Ins, RetCC_TriCore);

  // Copy all of the result registers out of their specified physreg.
  for (auto &VA : RVLocs) {
    Chain =
        DAG.getCopyFromReg(Chain, dl, VA.getLocReg(), VA.getValVT(), InGlue)
            .getValue(1);
    InGlue = Chain.getValue(2);
    InVals.push_back(Chain.getValue(0));
  }

  return Chain;
}

//===----------------------------------------------------------------------===//
//             Formal Arguments Calling Convention Implementation
//===----------------------------------------------------------------------===//

/// TriCore formal arguments implementation

// Called when function in entered
SDValue TriCoreTargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool isVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &dl,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MachineRegisterInfo &RegInfo = MF.getRegInfo();

  // Assign locations to all of the incoming arguments.
  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CallConv, isVarArg, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_TriCore);

  // CC_TriCore routes each argument to the correct physical register class:
  //   CCIfPtr → A4-A7  (AddrRegsRegClass)
  //   i64     → E4/E6  (ExtRegsRegClass)
  //   i32     → D4-D7  (DataRegsRegClass)
  // We detect the class from the assigned physical register so no external
  // bookkeeping is needed.
  for (CCValAssign &VA : ArgLocs) {
    if (VA.isRegLoc()) {
      // Determine the register class from the assigned physical register.
      const TargetRegisterClass *RC;
      EVT CopyVT;
      if (TriCore::AddrRegsRegClass.contains(VA.getLocReg())) {
        RC = &TriCore::AddrRegsRegClass;
        CopyVT = MVT::i32;
      } else if (TriCore::ExtRegsRegClass.contains(VA.getLocReg())) {
        RC = &TriCore::ExtRegsRegClass;
        CopyVT = MVT::i64;
      } else {
        RC = &TriCore::DataRegsRegClass;
        CopyVT = MVT::i32;
      }

      unsigned VReg = RegInfo.createVirtualRegister(RC);
      RegInfo.addLiveIn(VA.getLocReg(), VReg);
      SDValue ArgIn = DAG.getCopyFromReg(Chain, dl, VReg, CopyVT);

      // Handle value extensions for i8/i16 arguments that were promoted to
      // i32 by CC_TriCore.
      switch (VA.getLocInfo()) {
      default:
        llvm_unreachable("Unknown loc info!");
      case CCValAssign::Full:
        break;
      case CCValAssign::BCvt:
        ArgIn = DAG.getNode(ISD::BITCAST, dl, VA.getValVT(), ArgIn);
        break;
      case CCValAssign::SExt:
        ArgIn = DAG.getNode(ISD::AssertSext, dl, CopyVT, ArgIn,
                            DAG.getValueType(VA.getValVT()));
        ArgIn = DAG.getNode(ISD::TRUNCATE, dl, VA.getValVT(), ArgIn);
        break;
      case CCValAssign::ZExt:
        ArgIn = DAG.getNode(ISD::AssertZext, dl, CopyVT, ArgIn,
                            DAG.getValueType(VA.getValVT()));
        ArgIn = DAG.getNode(ISD::TRUNCATE, dl, VA.getValVT(), ArgIn);
        break;
      }

      InVals.push_back(ArgIn);
      continue;
    }

    assert(VA.isMemLoc() &&
           "Can only pass arguments as either registers or via the stack");

    const unsigned Offset = VA.getLocMemOffset();
    uint64_t ObjSize = (VA.getValVT() == MVT::i64) ? 8 : 4;
    const int FI = MF.getFrameInfo().CreateFixedObject(ObjSize, Offset, true);
    EVT PtrTy = getPointerTy(DAG.getDataLayout());
    SDValue FIPtr = DAG.getFrameIndex(FI, PtrTy);

    // Create a load node for the argument on the stack.
    SDValue Load =
        DAG.getLoad(VA.getValVT(), dl, Chain, FIPtr, MachinePointerInfo());
    InVals.push_back(Load);
  }

  // For vararg functions, record the frame index of the first variadic
  // argument.  va_start uses this to initialise the va_list pointer.
  if (isVarArg) {
    TriCoreFunctionInfo *FuncInfo = MF.getInfo<TriCoreFunctionInfo>();
    int VarArgsFI = MF.getFrameInfo().CreateFixedObject(
        4, CCInfo.getNextStackOffset(), true);
    FuncInfo->setVarArgsFrameOffset(VarArgsFI);
  }

  return Chain;
}

//===----------------------------------------------------------------------===//
//               Return Value Calling Convention Implementation
//===----------------------------------------------------------------------===//

bool TriCoreTargetLowering::CanLowerReturn(
    CallingConv::ID CallConv, MachineFunction &MF, bool isVarArg,
    const SmallVectorImpl<ISD::OutputArg> &Outs, LLVMContext &Context) const {
  SmallVector<CCValAssign, 16> RVLocs;
  CCState CCInfo(CallConv, isVarArg, MF, RVLocs, Context);
  if (!CCInfo.CheckReturn(Outs, RetCC_TriCore)) {
    return false;
  }
  if (CCInfo.getNextStackOffset() != 0 && isVarArg) {
    return false;
  }
  return true;
}

SDValue
TriCoreTargetLowering::LowerReturn(SDValue Chain, CallingConv::ID CallConv,
                                   bool isVarArg,
                                   const SmallVectorImpl<ISD::OutputArg> &Outs,
                                   const SmallVectorImpl<SDValue> &OutVals,
                                   const SDLoc &dl, SelectionDAG &DAG) const {
  if (isVarArg)
    report_fatal_error("VarArg not supported");

  // CCValAssign - represent the assignment of
  // the return value to a location
  SmallVector<CCValAssign, 16> RVLocs;

  // CCState - Info about the registers and stack slot.
  // RetCC_TriCore assigns pointer returns to A2 via CCIfPtr, so no manual
  // override is needed here.
  CCState CCInfo(CallConv, isVarArg, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeReturn(Outs, RetCC_TriCore);

  SDValue Flag;
  SmallVector<SDValue, 4> RetOps(1, Chain);

  // Copy the result values into the output registers.
  for (unsigned i = 0, e = RVLocs.size(); i < e; ++i) {
    CCValAssign &VA = RVLocs[i];
    assert(VA.isRegLoc() && "Can only return in registers!");

    Chain = DAG.getCopyToReg(Chain, dl, VA.getLocReg(), OutVals[i], Flag);

    Flag = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
  }

  RetOps[0] = Chain; // Update chain.

  // Add the flag if we have it.
  if (Flag.getNode())
    RetOps.push_back(Flag);

  return DAG.getNode(TriCoreISD::RET_FLAG, dl, MVT::Other, RetOps);
}
