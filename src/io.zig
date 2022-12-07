const std = @import("std");
const testing = std.testing;
const os = std.os;
const linux = std.os.linux;
const IO_Uring = linux.IO_Uring;

const IO = struct {
    ring: IO_Uring,
    pub fn init() !IO {
        return IO{ .ring = try IO_Uring.init(2, 0) };
    }
    pub fn deinit(self: *IO) void {
        self.ring.deinit();
    }
    pub fn tick(self: *IO) !void {
        _ = try self.ring.submit();
        const cqe = try self.ring.copy_cqe();
        _ = cqe;
    }
};

pub const Completion = struct {
    result: i32 = undefined,
    // next: ?*Completion = null,
    // operation: Operation,
    context: ?*anyopaque,
    callback: *const fn (context: ?*anyopaque, completion: *Completion, result: *const anyopaque) void,
};

test {
    var io = try IO.init();
    var completion: Completion = undefined;

    var buffer_read = [_]u8{0} ** 10;
    _ = try io.ring.read(@ptrToInt(&completion), linux.STDIN_FILENO, .{ .buffer = &buffer_read }, 0);
    try io.tick();
}
