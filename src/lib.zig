pub const Client = @import("display.zig").Client;
pub const Argument = @import("argument.zig").Argument;
pub const Proxy = @import("proxy.zig").Proxy;
pub const shm = @import("shm.zig");

pub const wl = @import("generated/wl.zig");
pub const xdg = @import("generated/xdg.zig");
pub const zwlr = @import("generated/zwlr.zig");

const std = @import("std");
pub const IO = @import("./io_async.zig").IO;
// pub const IO = @import("./io_blocking.zig").IO;
const libcoro = @import("libcoro");
const root = @import("root");


pub fn my_main() void {
    const allocator = std.heap.page_allocator;
    run_async(allocator, async_main_w);
}
pub fn async_main_w(io: *IO) void {
    return root.async_main(io) catch unreachable;
}

pub fn run_async(allocator: std.mem.Allocator, func: anytype) void {
    const stack = libcoro.stackAlloc(
        allocator,
        1024 * 32,
    ) catch @panic("oom");

    var io = IO.init(32, 0) catch unreachable;
    defer io.deinit();

    if (!io.blocking) {
        var frame = try libcoro.xasync(func, .{&io}, stack);
        _ = &frame;
        io.run() catch unreachable;
    } else {
        const a = func(&io);
        _ = a;
    }
    // nosuspend await frame catch unreachable;

    // _ = a catch {};

}
