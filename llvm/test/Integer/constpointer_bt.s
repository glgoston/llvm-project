	.text
	.file	"constpointer_bt.ll"
	.type	t3,@object                      # @t3
	.data
	.globl	t3
	.p2align	2, 0x0
t3:
	.word	t1
	.size	t3, 4

	.type	t1,@object                      # @t1
	.globl	t1
	.p2align	2, 0x0
t1:
	.word	4                               # 0x4
	.byte	0
	.zero	3
	.size	t1, 8

	.type	t4,@object                      # @t4
	.globl	t4
	.p2align	2, 0x0
t4:
	.word	t3
	.size	t4, 4

	.type	t2,@object                      # @t2
	.globl	t2
	.p2align	2, 0x0
t2:
	.word	t1
	.size	t2, 4

	.type	__unnamed_1,@object             # @0
	.globl	__unnamed_1
	.p2align	2, 0x0
__unnamed_1:
	.word	__unnamed_2
	.size	__unnamed_1, 4

	.type	__unnamed_3,@object             # @1
	.globl	__unnamed_3
	.p2align	2, 0x0
__unnamed_3:
	.word	__unnamed_2
	.size	__unnamed_3, 4

	.type	__unnamed_2,@object             # @2
	.section	.bss,"aw",@nobits
	.globl	__unnamed_2
	.p2align	2, 0x0
__unnamed_2:
	.word	0x00000000                      # float 0
	.size	__unnamed_2, 4

	.type	__unnamed_4,@object             # @3
	.data
	.globl	__unnamed_4
	.p2align	2, 0x0
__unnamed_4:
	.word	__unnamed_2
	.size	__unnamed_4, 4

	.type	fptr,@object                    # @fptr
	.globl	fptr
	.p2align	2, 0x0
fptr:
	.word	f
	.size	fptr, 4

	.type	sptr1,@object                   # @sptr1
	.globl	sptr1
	.p2align	2, 0x0
sptr1:
	.word	somestr
	.size	sptr1, 4

	.type	somestr,@object                 # @somestr
	.section	.rodata,"a",@progbits
	.globl	somestr
somestr:
	.ascii	"hello world"
	.size	somestr, 11

	.type	sptr2,@object                   # @sptr2
	.data
	.globl	sptr2
	.p2align	2, 0x0
sptr2:
	.word	somestr
	.size	sptr2, 4

	.section	".note.GNU-stack","",@progbits
