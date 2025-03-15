pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    try app.layout.init(app.client.allocator);

    const flex = app.layout.add2(.flex, .{});
    const children = try app.client.allocator.alloc(widget.WidgetIdx, 3);
    children[0] = app.layout.add(.{ .type = .button });
    children[1] = app.layout.add(.{ .type = .button, .flex = 1 });
    children[2] = app.layout.add(.{ .type = .label });
    app.layout.set(flex, .children, children);

    const surface = try app.new_surface(.{ .wlr_layer_surface = .{
        .layer = .top,
        .anchor = .{},
        .size = .{ .width = 200, .height = 200 },
    } }, flex);

    app.client.request(
        surface.role.wlr_layer_surface,
        .set_keyboard_interactivity,
        .{ .keyboard_interactivity = .exclusive },
    );

    try app.client.recvEvents();
}

const std = @import("std");
const tk = @import("toolkit");
const App = tk.App;
const widget = tk.widget;
