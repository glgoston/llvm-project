add_llvm_component_library(LLVMTriCoreDisassembler
  TriCoreDisassembler.cpp

  LINK_COMPONENTS
  MCDisassembler
  TriCoreDesc
  TriCoreInfo
  MC
  Support

  ADD_TO_COMPONENT
  TriCore
)

target_compile_options(LLVMTriCoreDisassembler PRIVATE -g)
