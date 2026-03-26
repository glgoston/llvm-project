# RUN: llvm-mc -triple=tricore -filetype=obj %s -o %t.o
# RUN: llvm-readobj --elf-output-style=GNU -h %t.o | FileCheck --check-prefix=HEADER %s
# RUN: llvm-readobj --elf-output-style=GNU -S %t.o | FileCheck --check-prefix=SECTIONS %s
# RUN: llvm-readobj --elf-output-style=GNU -r %t.o | FileCheck --check-prefix=RELOCS %s

# Test that llvm-readobj correctly displays TriCore ELF files

.text
.globl main
main:
  call bar
  ret

.data
.globl mydata
mydata:
  .long 42
  .long bar

# HEADER: Machine:{{.*}}Siemens Tricore

# SECTIONS: Section Headers:
# SECTIONS: .text
# SECTIONS-SAME: AX
# SECTIONS: .data
# SECTIONS-SAME: WA

# RELOCS: Relocation section '.rel.text'
# RELOCS: R_TRICORE_24REL{{.*}}bar

# RELOCS: Relocation section '.rel.data'
# RELOCS: R_TRICORE_32ABS{{.*}}bar
