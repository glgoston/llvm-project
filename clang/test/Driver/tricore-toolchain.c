// RUN: %clang -target tricore-unknown-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -target tricore-pc-none-elf -v 2> %t
// RUN: grep 'Target: tricore' %t

// RUN: %clang -### %s -target tricore-unknown-elf -mcpu=tc162 2>&1 \
// RUN:   | FileCheck -check-prefix=CPU %s

// RUN: %clang -### -target tricore-unknown-elf -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=IAS-DEFAULT %s

// RUN: %clang -### -target tricore-unknown-elf -fno-integrated-as -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=NO-IAS %s

// RUN: not %clang -target tricore-unknown-elf -mcpu=not-a-cpu -c %s 2>&1 \
// RUN:   | FileCheck -check-prefix=BADCPU %s

// CPU: "-target-cpu" "tc162"
// IAS-DEFAULT: "-cc1"
// IAS-DEFAULT: "-emit-obj"
// IAS-DEFAULT-NOT: "{{.*}}/as"
// NO-IAS: "-no-integrated-as"
// NO-IAS: "{{.*}}/as"
// BADCPU: error: unknown target CPU 'not-a-cpu'
