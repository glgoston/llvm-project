//=- TriCoreCallingConv.td - Calling Conventions for TriCore -*- tablegen -*-=//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
// This describes the calling conventions for TriCore architecture.
// Reference: TriCore EABI v2.3
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// TriCore Return Value Calling Convention
//===----------------------------------------------------------------------===//
def RetCC_TriCore : CallingConv<[
  // Promote i8/i16 return values to i32.
  CCIfType<[i8, i16], CCPromoteToType<i32>>,

  // Pointer return values go in A2.
  CCIfPtr<CCAssignToReg<[A2]>>,

  // i32 return values go in D2.
  CCIfType<[i32], CCAssignToReg<[D2]>>,

  // i64 return values go in E2 (= D2:D3).
  CCIfType<[i64], CCAssignToReg<[E2]>>
]>;

//===----------------------------------------------------------------------===//
// TriCore Argument Calling Conventions
//===----------------------------------------------------------------------===//
def CC_TriCore : CallingConv<[
  // Promote i8/i16 arguments to i32.
  CCIfType<[i8, i16], CCPromoteToType<i32>>,

  // Pointer arguments are passed in address registers A4-A7.
  // CCIfPtr checks ArgFlags.isPointer() which LLVM sets for IR pointer types.
  CCIfPtr<CCAssignToReg<[A4, A5, A6, A7]>>,

  // i64 arguments are passed in extended register pairs E4, E6.
  CCIfType<[i64], CCAssignToReg<[E4, E6]>>,

  // i32 arguments are passed in data registers D4-D7.
  CCIfType<[i32], CCAssignToReg<[D4, D5, D6, D7]>>,

  // Remaining arguments are passed on the stack, 4-byte slots, 4-byte aligned.
  CCIfType<[i32], CCAssignToStack<4, 4>>,
  CCIfType<[i64], CCAssignToStack<8, 4>>
]>;

//===----------------------------------------------------------------------===//
// Callee-Saved Registers (TriCore EABI upper context)
//===----------------------------------------------------------------------===//
// Per TriCore EABI: upper data registers D8-D15 and upper address registers
// A10-A15 are callee-saved.  A10 (SP) and A11 (RA) are also in this set
// because they must be preserved across calls; A10 is also stack-pointer so
// it is separately reserved.
def CSR_TriCore : CalleeSavedRegs<(add
    D8, D9, D10, D11, D12, D13, D14, D15,
    A10, A11, A12, A13, A14, A15)>;
