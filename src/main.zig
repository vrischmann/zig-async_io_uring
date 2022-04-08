const std = @import("std");
const crypto = std.crypto;
const fmt = std.fmt;
const debug = std.debug;
const os = std.os;

const IO_Uring = os.linux.IO_Uring;

const AsyncIOUring = @import("async_io_uring").AsyncIOUring;

const max_ring_entries = 512;

fn computeFileHash(ring: *AsyncIOUring, path: [:0]const u8) ![crypto.hash.Sha1.digest_length]u8 {
    const open_cqe = try ring.openat(
        os.linux.AT.FDCWD,
        path,
        0,
        0644,
        null,
        null,
    );
    const fd = @intCast(os.fd_t, open_cqe.res);

    var statx_buf: os.linux.Statx = undefined;
    _ = try ring.statx(
        fd,
        "",
        os.linux.AT.EMPTY_PATH,
        os.linux.STATX_SIZE,
        &statx_buf,
        null,
        null,
    );

    // Read and compute hash

    var hasher = crypto.hash.Sha1.init(.{});

    var n: u64 = 0;
    while (n < statx_buf.size) {
        var buf: [4096]u8 = undefined;
        _ = buf;

        const cqe = try ring.read(
            fd,
            &buf,
            n,
            null,
            null,
        );

        const read = @intCast(u64, cqe.res);
        n += read;

        hasher.update(buf[0..read]);
    }

    var hash: [crypto.hash.Sha1.digest_length]u8 = undefined;
    hasher.final(&hash);

    return hash;
}

fn runEventLoop(frame: *@Frame(computeFileHash), file_path: [:0]const u8) !void {
    var ring = try IO_Uring.init(max_ring_entries, 0);
    defer ring.deinit();

    var async_ring = AsyncIOUring{ .ring = &ring };
    try async_ring.run_event_loop();

    frame.* = async computeFileHash(&async_ring, file_path);

    return async_ring.run_event_loop();
}

pub fn main() anyerror!void {
    const file_path = "/home/vincent/Music/Nemophila/NEMOPHILA-REVIVE/01-02-NEMOPHILA-DISSENSION-SMR.flac";

    var file_hash_frame: @Frame(computeFileHash) = undefined;

    var thread = try std.Thread.spawn(.{}, runEventLoop, .{
        &file_hash_frame,
        file_path,
    });

    debug.print("joining thread\n", .{});
    thread.join();
    debug.print("joined thread\n", .{});

    //

    const file_hash = try nosuspend await file_hash_frame;

    debug.print("file hash: {s}\n", .{
        fmt.fmtSliceHexLower(&file_hash),
    });
}
