add_llvm_library(LLVMTriCoreDesc
  TriCoreMCTargetDesc.cpp
  TriCoreMCAsmInfo.cpp
  TriCoreMCCodeEmitter.cpp
  TriCoreAsmBackend.cpp
  TriCoreELFObjectWriter.cpp
  TriCoreInstPrinter.cpp
  )

target_compile_options(LLVMTriCoreDesc PRIVATE -g)
