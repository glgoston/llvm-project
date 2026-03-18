add_llvm_component_group(TriCore)

set(LLVM_TARGET_DEFINITIONS TriCore.td)

tablegen(LLVM TriCoreGenGlobalISel.inc       -gen-global-isel)
tablegen(LLVM TriCoreGenRegisterInfo.inc     -gen-register-info)
tablegen(LLVM TriCoreGenRegisterBank.inc     -gen-register-bank)
tablegen(LLVM TriCoreGenInstrInfo.inc        -gen-instr-info)
tablegen(LLVM TriCoreGenSubtargetInfo.inc    -gen-subtarget)
tablegen(LLVM TriCoreGenMCCodeEmitter.inc    -gen-emitter)
tablegen(LLVM TriCoreGenMCPseudoLowering.inc -gen-pseudo-lowering)
tablegen(LLVM TriCoreGenDAGISel.inc          -gen-dag-isel)
tablegen(LLVM TriCoreGenCallingConv.inc      -gen-callingconv)
tablegen(LLVM TriCoreGenAsmWriter.inc        -gen-asm-writer)
tablegen(LLVM TriCoreGenAsmMatcher.inc       -gen-asm-matcher)
tablegen(LLVM TriCoreGenDisassemblerTable.inc -gen-disassembler)

add_public_tablegen_target(TriCoreCommonTableGen)

add_llvm_target(TriCoreCodeGen
  TriCoreSubtarget.cpp
  TriCoreTargetMachine.cpp
  TriCoreRegisterInfo.cpp
  TriCoreInstrInfo.cpp
  TriCoreFrameLowering.cpp
  TriCoreISelLowering.cpp
  TriCoreSelectionDAGInfo.cpp
  TriCoreISelDAGToDAG.cpp
  TriCoreAsmPrinter.cpp
  TriCoreMCInstLower.cpp
  TriCoreTargetObjectFile.cpp

  LINK_COMPONENTS
  Analysis
  AsmPrinter
  CodeGen
  Core
  GlobalISel
  MC
  SelectionDAG
  Support
  Target
  TriCoreDesc
  TriCoreInfo

  ADD_TO_COMPONENT
  TriCore
)

add_subdirectory(TargetInfo)
add_subdirectory(MCTargetDesc)
add_subdirectory(AsmParser)
#add_subdirectory(Disassembler)
