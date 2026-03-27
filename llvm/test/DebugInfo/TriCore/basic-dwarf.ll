; RUN: llc -mtriple=tricore -filetype=obj %s -o %t.o
; RUN: llvm-readobj --sections %t.o | FileCheck %s

; Check that DWARF debug sections are generated for TriCore.

; CHECK-DAG: Name: .debug_info
; CHECK-DAG: Name: .debug_abbrev
; CHECK-DAG: Name: .debug_line

define i32 @test_function(i32 %x) !dbg !7 {
entry:
  %result = add i32 %x, 42, !dbg !11
  ret i32 %result, !dbg !12
}

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4, !5}
!llvm.ident = !{!6}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "clang", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !2)
!1 = !DIFile(filename: "test.c", directory: "/tmp")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"wchar_size", i32 4}
!6 = !{!"clang"}
!7 = distinct !DISubprogram(name: "test_function", scope: !1, file: !1, line: 1, type: !8, scopeLine: 1, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !2)
!8 = !DISubroutineType(types: !9)
!9 = !{!10, !10}
!10 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!11 = !DILocation(line: 2, column: 12, scope: !7)
!12 = !DILocation(line: 2, column: 3, scope: !7)
