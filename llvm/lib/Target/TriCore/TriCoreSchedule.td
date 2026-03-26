//===-- TriCoreSchedule.td - TriCore Scheduling Definitions -*- tablegen -*-===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//
//
// This file defines the in-order scheduling model for TriCore TC1.6E/TC1.6P.
//
// Pipeline overview (TC1.6E/TC1.6P):
//   - 5-stage in-order: Instruction Fetch → Decode/Operand Addr → Execute/LS → WB
//   - Single-issue; no out-of-order execution
//   - Separate integer, load/store, multiply/MAC/divide, and FP execution units
//
// Reference instruction latencies (TriCore TC1.6E/P Architecture Manual vol. 2):
//   Integer ALU (add, sub, logical, shift, compare, move): 1 cycle
//   Saturating ALU (adds, subs, abss):                     1 cycle
//   Load  (ld.w, ld.b, ld.h, ld.a, ld.d):                 2 cycles
//   Store (st.w, st.b, st.h, st.a, st.d):                  2 cycles (LS unit)
//   Multiply (mul, mulu):                                   3 cycles (TC1.6E)
//   MAC (madd, msub, madds, msubs, etc.):                   3 cycles
//   Divide (div, div.u):                                    8+ cycles
//   Branch / Call / Return:                                 1 cycle
//   FP arithmetic (add.f, sub.f, mul.f):                   4 cycles
//   FP fused multiply-add (madd.f, msub.f):                5 cycles
//   FP divide (div.f):                                      8 cycles
//   FP convert (itof, utof, ftoiz, ftouz, qseed.f):         3 cycles
//   FP compare (cmp.f):                                     2 cycles
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Functional units — TriCore TC1.6E/TC1.6P
//===----------------------------------------------------------------------===//

def TC_Int : FuncUnit;   // Integer ALU, logical, shift, compare, move, branch
def TC_Ls  : FuncUnit;   // Load / Store unit
def TC_Mac : FuncUnit;   // Multiply / MAC / Divide unit
def TC_Fp  : FuncUnit;   // IEEE 754 single-precision FP unit (tc162+)

//===----------------------------------------------------------------------===//
// Instruction itinerary classes
//===----------------------------------------------------------------------===//

def IIC_ALU   : InstrItinClass;   // Integer ALU (add, sub, logical, cmp, mov): 1 cycle
def IIC_SAT   : InstrItinClass;   // Saturating ALU (adds, subs, abss): 1 cycle
def IIC_LD    : InstrItinClass;   // Load: 2 cycles
def IIC_ST    : InstrItinClass;   // Store: 2 cycles
def IIC_MUL   : InstrItinClass;   // Integer multiply (mul, mulu): 3 cycles
def IIC_MAC   : InstrItinClass;   // Integer MAC (madd, msub, etc.): 3 cycles
def IIC_DIV   : InstrItinClass;   // Integer divide (div, div.u): 8+ cycles
def IIC_BR    : InstrItinClass;   // Branch / Call / Return: 1 cycle
def IIC_FP    : InstrItinClass;   // FP arithmetic (add.f, sub.f, mul.f): 4 cycles
def IIC_FPDIV : InstrItinClass;   // FP divide (div.f): 8 cycles
def IIC_FPCVT : InstrItinClass;   // FP convert (itof, utof, etc.): 3 cycles
def IIC_FPCMP : InstrItinClass;   // FP compare (cmp.f): 2 cycles

//===----------------------------------------------------------------------===//
// Processor itineraries
//===----------------------------------------------------------------------===//

def TriCoreItinerary : ProcessorItineraries<
    [TC_Int, TC_Ls, TC_Mac, TC_Fp], [], [
  InstrItinData<IIC_ALU,   [InstrStage<1, [TC_Int]>]>,
  InstrItinData<IIC_SAT,   [InstrStage<1, [TC_Int]>]>,
  InstrItinData<IIC_LD,    [InstrStage<2, [TC_Ls]>]>,
  InstrItinData<IIC_ST,    [InstrStage<2, [TC_Ls]>]>,
  InstrItinData<IIC_MUL,   [InstrStage<3, [TC_Mac]>]>,
  InstrItinData<IIC_MAC,   [InstrStage<3, [TC_Mac]>]>,
  InstrItinData<IIC_DIV,   [InstrStage<8, [TC_Mac]>]>,
  InstrItinData<IIC_BR,    [InstrStage<1, [TC_Int]>]>,
  InstrItinData<IIC_FP,    [InstrStage<4, [TC_Fp]>]>,
  InstrItinData<IIC_FPDIV, [InstrStage<8, [TC_Fp]>]>,
  InstrItinData<IIC_FPCVT, [InstrStage<3, [TC_Fp]>]>,
  InstrItinData<IIC_FPCMP, [InstrStage<2, [TC_Fp]>]>
]>;

//===----------------------------------------------------------------------===//
// Machine scheduler model (MachineScheduler / post-RA scheduler)
//===----------------------------------------------------------------------===//

def TriCoreSchedModel : SchedMachineModel {
  // TriCore TC1.6E/TC1.6P is a single-issue in-order pipeline.
  let IssueWidth        = 1;     // One instruction issued per cycle.
  let MicroOpBufferSize = 0;     // In-order: no out-of-order buffer.
  let LoadLatency       = 2;     // Load-to-use stall: 2 cycles.
  let MispredictPenalty = 5;     // Branch misprediction penalty (approximate).
  let CompleteModel     = 0;     // Allow unmodelled instructions (Pseudo, etc.).
  let PostRAScheduler   = 1;     // Enable post-register-allocation scheduling.
  let Itineraries       = TriCoreItinerary;
}

//===----------------------------------------------------------------------===//
// Processor resource units (for WriteRes definitions used by MachineScheduler)
//===----------------------------------------------------------------------===//

def TC_IntRes : ProcResource<1> { let BufferSize = 0; }
def TC_LsRes  : ProcResource<1> { let BufferSize = 0; }
def TC_MacRes : ProcResource<1> { let BufferSize = 0; }
def TC_FpRes  : ProcResource<1> { let BufferSize = 0; }

//===----------------------------------------------------------------------===//
// Scheduling write types
//===----------------------------------------------------------------------===//

def WriteALU   : SchedWrite;
def WriteSAT   : SchedWrite;
def WriteLD    : SchedWrite;
def WriteST    : SchedWrite;
def WriteMUL   : SchedWrite;
def WriteMAC   : SchedWrite;
def WriteDIV   : SchedWrite;
def WriteBR    : SchedWrite;
def WriteFP    : SchedWrite;
def WriteFPDIV : SchedWrite;
def WriteFPCVT : SchedWrite;
def WriteFPCMP : SchedWrite;

let SchedModel = TriCoreSchedModel in {
  def : WriteRes<WriteALU,   [TC_IntRes]> { let Latency = 1; }
  def : WriteRes<WriteSAT,   [TC_IntRes]> { let Latency = 1; }
  def : WriteRes<WriteLD,    [TC_LsRes]>  { let Latency = 2; }
  def : WriteRes<WriteST,    [TC_LsRes]>  { let Latency = 2; }
  def : WriteRes<WriteMUL,   [TC_MacRes]> { let Latency = 3; }
  def : WriteRes<WriteMAC,   [TC_MacRes]> { let Latency = 3; }
  def : WriteRes<WriteDIV,   [TC_MacRes]> { let Latency = 8; }
  def : WriteRes<WriteBR,    [TC_IntRes]> { let Latency = 1; }
  def : WriteRes<WriteFP,    [TC_FpRes]>  { let Latency = 4; }
  def : WriteRes<WriteFPDIV, [TC_FpRes]>  { let Latency = 8; }
  def : WriteRes<WriteFPCVT, [TC_FpRes]>  { let Latency = 3; }
  def : WriteRes<WriteFPCMP, [TC_FpRes]>  { let Latency = 2; }
}
