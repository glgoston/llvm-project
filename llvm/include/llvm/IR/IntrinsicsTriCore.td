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

  // Integer multiply-accumulate/subtract on TC1.6P MAC cores.
  // Semantics:
  //   madd.i32(acc, x, y) = acc + (x * y)
  //   msub.i32(acc, x, y) = acc - (x * y)
  def int_tricore_madd_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_msub_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;


  // Saturating absolute value on TC1.6P MAC cores.
  // abss.i32(x) = (x == INT_MIN) ? INT_MAX : abs(x)
  // abssh.i32(x) = packed halfword saturating abs:
  //   each 16-bit half h: (h == INT16_MIN) ? INT16_MAX : abs(h)
  def int_tricore_abss_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_abssh_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;

  // Unsigned saturating multiply-accumulate/subtract on TC1.6P MAC cores.
  // Maps to MADDS.U / MSUBS.U (RRR2, the only unsigned 32-bit D-reg MAC form).
  //   maddsu.i32(acc, x, y) = suov(acc + x*y, 32)  [unsigned saturated]
  //   msubsu.i32(acc, x, y) = suov(acc - x*y, 32)  [unsigned saturated]
  def int_tricore_maddsu_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_msubsu_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;

  // Extended (64-bit E-reg) unsigned MAC: MADD.U / MSUB.U (RRR2 form).
  //   maddu.i64(acc, x, y) = E[acc] + D[x]*D[y]  (unsigned 64-bit result)
  //   msubu.i64(acc, x, y) = E[acc] - D[x]*D[y]  (unsigned 64-bit result)
  def int_tricore_maddu_i64 : DefaultAttrsIntrinsic<[llvm_i64_ty],
                                            [llvm_i64_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_msubu_i64 : DefaultAttrsIntrinsic<[llvm_i64_ty],
                                            [llvm_i64_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;

  // Q-format (fractional 32-bit) MAC: MADD.Q / MSUB.Q (RRR1, n=1 form).
  //   maddq.i32(acc, x, y) = D[acc] + (((D[x]*D[y]) << 1) >> 32)
  //   msubq.i32(acc, x, y) = D[acc] - (((D[x]*D[y]) << 1) >> 32)
  def int_tricore_maddq_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_msubq_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;

  // Signed saturating 32-bit MAC: MADDS / MSUBS (RRR2, op2=0x8A).
  //   madds.i32(acc, x, y) = ssov(D[acc] + D[x]*D[y], 32)
  //   msubs.i32(acc, x, y) = ssov(D[acc] - D[x]*D[y], 32)
  def int_tricore_madds_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
  def int_tricore_msubs_i32 : DefaultAttrsIntrinsic<[llvm_i32_ty],
                                            [llvm_i32_ty, llvm_i32_ty, llvm_i32_ty],
                                            [IntrNoMem, IntrSpeculatable]>;

  // QSEED.F: compute an approximate seed value for 1/sqrt(src).
  // Maps to the TC1.6 QSEED.F instruction (op1=0x4B, op2=0x06, n=0b10).
  // Only meaningful on CPUs with FeatureFP (tc162+).
  def int_tricore_qseed_f32 : DefaultAttrsIntrinsic<[llvm_float_ty],
                                            [llvm_float_ty],
                                            [IntrNoMem, IntrSpeculatable]>;
}
