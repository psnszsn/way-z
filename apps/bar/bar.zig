pub const std_options = std.Options{
    .log_level = .info,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var app = try App.new(allocator);
    var bar = try app.new_window(.wlr_layer_shell);

    try app.layout.init(app.client.allocator);
    const flex = app.layout.add2(.flex, .{});
    const children = try app.client.allocator.alloc(widget.WidgetIdx, 3);
    children[0] = app.layout.add(.{ .type = .button });
    children[1] = app.layout.add(.{ .type = .button, .flex = 1 });
    children[2] = app.layout.add(.{ .type = .button });
    app.layout.set(flex, .children, children);
    bar.set_root_widget(flex);

    bar.draw();
    try app.client.roundtrip();

    try app.client.recvEvents();
}

const std = @import("std");
const tk = @import("toolkit");
const App = tk.App;
const widget = tk.widget;
