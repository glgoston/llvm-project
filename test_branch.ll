; Test: simple branch
define void @test_branch(i32 %x) {
entry:
  %cmp = icmp ne i32 %x, 0
  br i1 %cmp, label %bb1, label %bb2
bb1:
  ret void
bb2:
  ret void
}
