//==- IntrinsicsTriCore.td - TriCore intrinsics             -*- tablegen -*-==//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file defines TriCore-specific intrinsics.
//
//===----------------------------------------------------------------------===//

let TargetPrefix = "tricore" in {  // All intrinsics start with "llvm.tricore.".

  // QSEED.F: compute an approximate seed value for 1/sqrt(src).
  // Maps to the TC1.6 QSEED.F instruction (op1=0x4B, op2=0x06, n=0b10).
  // Only meaningful on CPUs with FeatureFP (tc162+).
  def int_qseed_f32 : DefaultAttrsIntrinsic<[llvm_float_ty],
                                            [llvm_float_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
}
