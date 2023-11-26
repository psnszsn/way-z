
pub const Display = @import("display.zig").Display;
pub const Argument = @import("argument.zig").Argument;
pub const Proxy = @import("proxy.zig").Proxy;
pub const wl = @import("generated/wl.zig");

const std = @import("std");
pub const IO = @import("./io_async.zig").IO;
const libcoro = @import("libcoro");

pub fn run_async(allocator: std.mem.Allocator, func: anytype) !void {
    const stack = try libcoro.stackAlloc(
        allocator,
        1024 * 32,
    );

    var io = IO.init(32, 0) catch unreachable;
    defer io.deinit();
    // var f1 = async signals(&io);
    var frame = try libcoro.xasync(func, .{&io}, stack);
    _ = &frame;
    io.run() catch unreachable;
    // nosuspend await frame catch unreachable;

}
