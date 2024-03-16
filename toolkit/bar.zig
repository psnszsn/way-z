const std = @import("std");
const wayland = @import("wayland");
const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const App = @import("App.zig");
const widget = @import("widget.zig");

pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    var bar = try app.new_window();

    try bar.layout.init(app.client.allocator);
    const flex = bar.layout.add(.{ .type = .flex });
    const children = try app.client.allocator.alloc(widget.WidgetIdx, 1);
    children[0] = bar.layout.add(.{ .type = .button });
    // children[1] = bar.layout.add(.{ .type = .button, .flex = 1 });
    // children[2] = bar.layout.add(.{ .type = .button });
    bar.layout.set(flex, .children, children);
    bar.set_root_widget(flex);

    bar.draw();
    try app.client.roundtrip();

    try app.client.recvEvents();
}
