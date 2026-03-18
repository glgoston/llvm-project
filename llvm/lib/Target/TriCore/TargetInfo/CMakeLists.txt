add_llvm_library(LLVMTriCoreInfo
  TriCoreTargetInfo.cpp
  )

target_compile_options(LLVMTriCoreInfo PRIVATE -g)
