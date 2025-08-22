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
    event_handler: ?*const fn (*anyopaque, WidgetIdx, *const anyopaque) void = null,
    event_handler_data: *anyopaque = undefined,
    // subsurface: ?@import("wayland").wl.Surface = null,
};

const root = @import("root");
pub const root_w_types = if (@hasDecl(root, "widget_types")) root.widget_types else .{};
const common_w_types = .{
    .flex = @import("widgets/Flex.zig"),
    .button = @import("widgets/Button.zig"),
    .label = @import("widgets/Label.zig"),
    .scrollable = @import("widgets/Scrollable.zig"),
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
        .@"enum" = .{
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

pub fn WidgetEvent(comptime self: WidgetType) type {
    return WidgetData(self).Event;
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
        return @typeInfo(Signature(self)).@"fn".return_type orelse void;
    }
};

pub const Layout = struct {
    widgets: std.MultiArrayList(WidgetAttrs) = .{},
    widget_alloc: std.heap.FixedBufferAllocator = undefined,

    pub fn init(self: *Layout, alloc: std.mem.Allocator) !void {
        try self.widgets.ensureTotalCapacity(alloc, 100);
        const widget_data = try alloc.alloc(u8, 5000);
        self.widget_alloc = std.heap.FixedBufferAllocator.init(widget_data);
    }
    pub fn deinit(self: *Layout, alloc: std.mem.Allocator) void {
        alloc.free(self.widget_alloc.buffer);
        self.widgets.deinit(alloc);
    }

    pub fn add4(self: *Layout, comptime t: WidgetType, opts: WidgetData(t).InitOpts) WidgetIdx {
        const idx = self.add2(t, undefined);
        WidgetData(t).init(self, idx, opts);
        return idx;
    }
    ///Add with children
    pub fn add3(self: *Layout, comptime t: WidgetType, wdata: WidgetData(t), children: []const WidgetIdx) WidgetIdx {
        const idx = self.add2(t, wdata);
        if (children.len > 1)
            for (children[1..], 0..) |child_idx, i| {
                std.debug.assert(@intFromEnum(child_idx) == @intFromEnum(children[i]) + 1);
            };
        self.set(idx, .children, children);
        return idx;
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

    pub fn set_data(layout: *const Layout, idx: WidgetIdx, field: u8, value: *const anyopaque) void {
        const t = layout.get(idx, .type);
        switch (t) {
            inline else => |wt| {
                if (std.meta.fields(WidgetData(wt)).len == 0) {
                    unreachable;
                }
                const _data = layout.data(idx, WidgetData(wt));
                const _field: std.meta.FieldEnum(WidgetData(wt)) = @enumFromInt(field);
                switch (_field) {
                    inline else => |f| {
                        const val: *const @FieldType(WidgetData(wt), @tagName(f)) = @ptrCast(@alignCast(value));
                        @field(_data, @tagName(f)) = val.*;
                    },
                }
            },
        }
        layout.request_draw(idx);
    }

    pub fn get_ptr(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
    ) *@FieldType(WidgetAttrs, @tagName(item)) {
        return &self.widgets.items(item)[@intFromEnum(idx)];
    }

    pub fn get(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
    ) @FieldType(WidgetAttrs, @tagName(item)) {
        return self.widgets.items(item)[@intFromEnum(idx)];
    }

    pub fn set(
        self: *const Layout,
        idx: WidgetIdx,
        comptime item: std.meta.FieldEnum(WidgetAttrs),
        value: @FieldType(WidgetAttrs, @tagName(item)),
    ) void {
        self.widgets.items(item)[@intFromEnum(idx)] = value;
        // if (item != .rect) return;
        // if (self.get(idx, .subsurface)) |wl_surface| {
        //     const subs = self.get_app().surfaces.getPtr(wl_surface).?;
        //     subs.role.wl_subsurface.set_position(value.x, value.y);
        // }
    }

    pub fn set_size(
        self: *Layout,
        idx: WidgetIdx,
        constraints: Size.Minmax,
    ) void {
        const size = self.call(idx, .size, .{constraints});
        self.set(idx, .rect, size.to_rect());
    }

    pub fn call_void(
        self: *Layout,
        idx: WidgetIdx,
        comptime func: []const u8,
        args: anytype,
    ) void {
        const t = self.get(idx, .type);

        switch (t) {
            inline else => |wt| {
                if (@hasDecl(WidgetData(wt), func)) {
                    const f = @field(WidgetData(wt), func);
                    return @call(.auto, f, .{ self, idx } ++ args);
                } else {
                    std.log.info("t={}", .{t});
                    @panic("asd");
                }
            },
        }
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
        const app: *App = @constCast(@fieldParentPtr("layout", self));
        if (app.active_surface) |active| {
            // std.log.warn("::::: {}", .{active.root});
            return app.surfaces.getPtr(active).?;
        }
        @panic("TODO");
        // return &app.surfaces.items[0];
    }

    pub fn get_app(
        self: *const Layout,
    ) *App {
        return @constCast(@fieldParentPtr("layout", self));
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

    pub fn set_handler(
        self: *Layout,
        idx: WidgetIdx,
        handler: anytype,
    ) void {
        const T = @typeInfo(@TypeOf(handler)).pointer.child;
        self.set(idx, .event_handler, @ptrCast(&T.handle_event));
        self.set(idx, .event_handler_data, @ptrCast(handler));
    }

    pub fn set_handler2(
        self: *Layout,
        idx: WidgetIdx,
        handler_fn: anytype,
        handler_data: anytype,
    ) void {
        self.set(idx, .event_handler, @ptrCast(handler_fn));
        self.set(idx, .event_handler_data, @ptrCast(handler_data));
    }

    pub fn absolute_rect(
        layout: *const Layout,
        idx: WidgetIdx,
    ) Rect {
        var r = layout.get(idx, .rect);
        var parent = layout.get(idx, .parent);
        while (parent) |par| {
            const parent_rect = layout.get(par, .rect);
            r.translate_by(parent_rect.x, parent_rect.y);
            parent = layout.get(par, .parent);
        }
        return r;
    }

    pub fn emit_event(
        self: *Layout,
        idx: WidgetIdx,
        event: *const anyopaque,
    ) void {
        const handler = self.get(idx, .event_handler);
        const handler_data = self.get(idx, .event_handler_data);

        if (handler) |h| {
            @call(.auto, h, .{ handler_data, idx, event });
        }
        // std.debug.assert(T.Event == @TypeOf(event));
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

    pub fn next_sibling(it: *ChildWidgetIterator) ?WidgetIdx {
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
        return null;
    }

    pub fn next(it: *ChildWidgetIterator) ?WidgetIdx {
        // defer std.debug.print("it.depth={}\n\n", .{it.depth});
        // defer std.debug.print("it.next_child_stack={any} depth={}\n\n", .{
        //     it.next_child_stack,
        //     it.depth,
        // });
        if (it.depth == 0 and it.next_child_stack[0] == 0) {
            it.depth += 1;
            return it.parent;
        }

        if (it.next_sibling()) |n| return n;

        // if there are no children, next is the first ancestor's sibling
        while (it.depth > 1) {
            it.next_child_stack[it.depth] = 0;
            it.depth -= 1;
            const grand_parent = it.layout.get(it.parent, .parent).?;
            it.parent = grand_parent;

            if (it.next_sibling()) |n| return n;
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

    const btn2_c1 = layout.add2(.button, .{});
    const btn2_c2 = layout.add2(.button, .{});

    layout.set(btn2, .children, &.{ btn2_c1, btn2_c2 });

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
    try std.testing.expectEqual(iter.next(), btn2_c1);
    try std.testing.expectEqual(iter.next(), btn2_c2);
    try std.testing.expectEqual(iter.next(), btn3);
    // std.debug.print("it={}\n", .{iter});
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
const Event = @import("event.zig").Event;
