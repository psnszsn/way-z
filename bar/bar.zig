const std = @import("std");
const wayland = @import("wayland");
const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const App = @import("App.zig");

pub const std_options = std.Options{
    .log_level = .info,
};


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();


    var app = try App.new(allocator);
    var bar = try app.new_window();

    const buf = try Buffer.get(bar.ctx.shm.?, bar.width, bar.height);

    const ctx = PaintCtx{
        .buffer = @ptrCast(std.mem.bytesAsSlice(u32, buf.pool.mmap)),
        .width = buf.width,
        .height = buf.height,
    };
    bar.layout.draw(ctx);
    bar.wl_surface.attach(buf.wl_buffer, 0, 0);
    bar.wl_surface.commit();
    try app.client.roundtrip();

    try app.client.recvEvents();
}

