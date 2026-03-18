	.text
	.file	"unreachable_bt.ll"
	.globl	foo                             # -- Begin function foo
	.type	foo,@function
foo:                                    # @foo
# %bb.0:
.Lfunc_end0:
	.size	foo, .Lfunc_end0-foo
                                        # -- End function
	.globl	xyz                             # -- Begin function xyz
	.type	xyz,@function
xyz:                                    # @xyz
# %bb.0:
	call bar
.Lfunc_end1:
	.size	xyz, .Lfunc_end1-xyz
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
