pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var app = try App.new(allocator, init.environ_map);

    try app.layout.init(app.client.allocator);
    const flex = app.layout.add2(.flex, .{});
    const children = try app.client.allocator.alloc(widget.WidgetIdx, 3);
    children[0] = app.layout.add(.{ .type = .button });
    children[1] = app.layout.add(.{ .type = .button, .flex = 1 });
    children[2] = app.layout.add(.{ .type = .button });
    app.layout.set(flex, .children, children);

    _ = try app.new_surface(.{ .wlr_layer_surface = .{
        .layer = .top,
        .anchor = .{ .top = true, .left = true, .right = true },
        .size = .{ .width = 0, .height = 30 },
    } }, flex);

    try app.client.recvEvents();
}

const std = @import("std");
const tk = @import("toolkit");
const App = tk.App;
const widget = tk.widget;
