# defaults to 100 & 100
ExUnit.configure(assert_receive_timeout: 1_000, refute_receive_timeout: 300, exclude: :operations)
ExUnit.start()
