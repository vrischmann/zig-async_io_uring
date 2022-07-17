# zig-async_io_uring

This is just a playground using https://github.com/saltzm/async_io_uring.

All the code does is computing a Blake3 checksum of a file and prints it, like `b3sum`.

The cool thing is it does it using Zig's `async`/`await` feature and `io_uring`.
