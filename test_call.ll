declare void @external_func()

define void @test_func() {
  call void @external_func()
  ret void
}
