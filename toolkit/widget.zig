pub const WidgetIdx = enum(u32) {
    _,
};

const WidgetAttrs = struct {
    type: WidgetType,
    rect: Rect = Rect.ZERO,
    flex: u8 = 0,
    hover: bool = false,
    pressed: bool = false,
    dirty: bool = false,
    children: []const WidgetIdx = &.{},
    parent: ?WidgetIdx = null,
    data: usize = undefined,
};

const root = @import("root");
pub const root_w_types = if (@hasDecl(root, "widget_types")) root.widget_types else .{};
const common_w_types = .{
    .flex = @import("widgets/Flex.zig"),
    .button = @import("widgets/Button.zig"),
    // .menu_bar = @import("widgets/MenuBar.zig"),
};
const widget_names = std.meta.fieldNames(@TypeOf(root_w_types)) ++ std.meta.fieldNames(@TypeOf(common_w_types));

/// A widget type has to implement the following functions:
/// pub fn handle_event(layout: *Layout, idx: WidgetIdx, event: Event) void {}
/// pub fn size(_: *Layout, _: WidgetIdx, _: Size.Minmax) Size {}
/// pub fn draw(layout: *Layout, idx: WidgetIdx, rect: Rect, paint_ctx: PaintCtx) bool {}
const WidgetType = b: {
    var enumFields: [widget_names.len]std.builtin.Type.EnumField = undefined;
    for (widget_names, 0..) |name, i| {
        enumFields[i] = .{
            .name = name,
            .value = i,
        };
    }
    break :b @Type(.{
        .Enum = .{
            .tag_type = u8,
            .fields = &enumFields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
};

pub fn WidgetData(comptime self: WidgetType) type {
    const tag_name = @tagName(self);
    if (@hasField(@TypeOf(common_w_types), tag_name)) {
        return @field(common_w_types, tag_name);
    }
    if (@hasField(@TypeOf(root_w_types), tag_name)) {
        return @field(root_w_types, tag_name);
    }
}

pub const WidgetFn = enum {
    size,
    draw,
    handle_event,

    pub fn Signature(comptime self: WidgetFn) type {
        return switch (self) {
            .size => fn (*Layout, WidgetIdx, Size.Minmax) Size,
            .draw => fn (*Layout, WidgetIdx, Rect, PaintCtx) bool,
            .handle_event => fn (*Layout, WidgetIdx, Event) void,
        };
    }
    pub fn ReturnType(comptime self: WidgetFn) type {
        return @typeInfo(Signature(self)).Fn.return_type orelse void;
    }
};

pub const Layout = struct {
    widgets: std.MultiArrayList(WidgetAttrs) = .{},
    widget_alloc: std.heap.FixedBufferAllocator = undefined,

    pub fn init(self: *Layout, alloc: std.mem.Allocator) !void {
        try self.widgets.ensureTotalCapacity(alloc, 100);
        const widget_data = try alloc.alloc(u8, 100);
        self.widget_alloc = std.heap.FixedBufferAllocator.init(widget_data);
    }
    pub fn deinit(self: *Layout, alloc: std.mem.Allocator) void {
        alloc.free(self.widget_alloc.buffer);
        self.widgets.deinit(alloc);
    }

    pub fn add2(self: *Layout, comptime t: WidgetType, wdata: WidgetData(t)) WidgetIdx {
        const idx = self.add(.{ .type = t });
        const w_data = if (@sizeOf(WidgetData(t)) <= @sizeOf(usize)) b: {
            break :b self.data(idx, WidgetData(t));
        } else b: {
            const w_data = self.widget_alloc.allocator().create(WidgetData(t)) catch @panic("TODO");
            self.set(idx, .data, @intFromPtr(w_data));
            break :b w_data;
        };
        w_data.* = wdata;
        return idx;
    }

    pub fn add(self: *Layout, widget: WidgetAttrs) WidgetIdx {
        self.widgets.appendAssumeCapacity(widget);
        return @enumFromInt(self.widgets.len - 1);
    }

    pub fn data(self: *const Layout, idx: WidgetIdx, T: type) *T {
        if (@sizeOf(T) <= @sizeOf(usize)) {
            return @ptrCast(&self.widgets.items(.data)[@intFromEnum(idx)]);
        } else {
            return @ptrFromInt(self.get(idx, .data));
        }
    }

    pub fn get(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
    ) std.meta.FieldType(WidgetAttrs, item) {
        return self.widgets.items(item)[@intFromEnum(idx)];
    }

    pub fn set(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
        value: std.meta.FieldType(WidgetAttrs, item),
    ) void {
        self.widgets.items(item)[@intFromEnum(idx)] = value;
    }

    pub fn call(
        self: *Layout,
        idx: WidgetIdx,
        comptime func: WidgetFn,
        args: anytype,
    ) WidgetFn.ReturnType(func) {
        const t = self.get(idx, .type);

        switch (t) {
            inline else => |wt| {
                const f = @field(WidgetData(wt), @tagName(func));
                return @call(.auto, f, .{ self, idx } ++ args);
            },
        }
    }

    const Window = @import("App.zig").Surface;
    const App = @import("App.zig");
    pub fn get_window(
        self: *const Layout,
    ) *Window {
        const app = @constCast(@fieldParentPtr(App, "layout", self));
        if (app.active_surface) |active| {
            // std.log.warn("::::: {}", .{active.root});
            return active;
        }
        return &app.surfaces.items[0];
    }

    pub fn get_app(
        self: *const Layout,
    ) *App {
        return @constCast(@fieldParentPtr(App, "layout", self));
    }

    pub fn request_draw(
        self: *const Layout,
        idx: WidgetIdx,
    ) void {
        self.set(idx, .dirty, true);
        self.get_window().schedule_redraw();
    }

    pub fn set_cursor_shape(
        self: *const Layout,
        shape: @import("wayland").wp.CursorShapeDeviceV1.Shape,
    ) void {
        const app = self.get_app();
        if (app.cursor_shape == shape) return;
        app.cursor_shape = shape;
    }

    pub fn child_iterator(
        layout: *Layout,
        idx: WidgetIdx,
    ) ChildWidgetIterator {
        return ChildWidgetIterator{
            .layout = layout,
            .parent = idx,
        };
    }
};

const ChildWidgetIterator = struct {
    layout: *Layout,
    parent: WidgetIdx,
    depth: u8 = 0,
    next_child_stack: [5]usize = .{0} ** 5,

    pub fn next(it: *ChildWidgetIterator) ?WidgetIdx {
        if (it.depth == 0 and it.next_child_stack[0] == 0) {
            it.depth += 1;
            return it.parent;
        }

        const parent_children = it.layout.get(it.parent, .children);
        if (it.next_child_stack[it.depth] < parent_children.len) {
            const new = parent_children[it.next_child_stack[it.depth]];
            const new_children = it.layout.get(new, .children);
            it.next_child_stack[it.depth] += 1;
            it.layout.set(new, .parent, it.parent);
            if (new_children.len > 0) {
                it.parent = new;
                it.depth += 1;
            }
            return new;
        }
        // if there are no children, next is the first ancestor's sibling
        while (it.depth > 1) {
            it.depth -= 1;
            const grand_parent = it.layout.get(it.parent, .parent).?;
            const grandparent_children = it.layout.get(grand_parent, .children);
            defer it.parent = grand_parent;
            if (it.next_child_stack[it.depth] < grandparent_children.len) {
                defer it.next_child_stack[it.depth] += 1;
                return grandparent_children[it.next_child_stack[it.depth]];
            }
        }

        return null;
    }
};

test ChildWidgetIterator {
    var layout = Layout{};
    try layout.init(std.testing.allocator);
    defer layout.deinit(std.testing.allocator);

    const flex = layout.add2(.flex, .{});
    const btn1 = layout.add2(.button, .{});
    const btn2 = layout.add2(.button, .{});
    const btn3 = layout.add2(.button, .{});
    const btn4 = layout.add2(.button, .{});

    layout.set(flex, .children, &.{ btn1, btn2, btn3, btn4 });

    const btn3_c1 = layout.add2(.button, .{});
    const btn3_c2 = layout.add2(.button, .{});

    layout.set(btn3, .children, &.{ btn3_c1, btn3_c2 });

    const btn3_c1_c1 = layout.add2(.button, .{});
    const btn3_c1_c2 = layout.add2(.button, .{});

    layout.set(btn3_c1, .children, &.{ btn3_c1_c1, btn3_c1_c2 });

    var iter = layout.child_iterator(flex);
    try std.testing.expectEqual(iter.next(), flex);
    try std.testing.expectEqual(iter.next(), btn1);
    try std.testing.expectEqual(iter.next(), btn2);
    try std.testing.expectEqual(iter.next(), btn3);
    try std.testing.expectEqual(iter.next(), btn3_c1);
    try std.testing.expectEqual(iter.next(), btn3_c1_c1);
    try std.testing.expectEqual(iter.next(), btn3_c1_c2);
    try std.testing.expectEqual(iter.next(), btn3_c2);
    try std.testing.expectEqual(iter.next(), btn4);
    try std.testing.expectEqual(iter.next(), null);
}

const std = @import("std");
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Rect = @import("paint/Rect.zig");
const Size = @import("paint/Size.zig");
const Point = @import("paint/Point.zig");
const Event = @import("event.zig").Event;
