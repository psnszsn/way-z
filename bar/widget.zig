const std = @import("std");
const mem = std.mem;
const os = std.os;

const wayland = @import("wayland");
const wl = wayland.wl;
const xdg = wayland.xdg;
const zwlr = wayland.zwlr;
const xev = @import("xev");

const font = @import("font/bdf.zig");

const Buffer = wayland.shm.Buffer;
const PaintCtx = @import("paint.zig").PaintCtxU32;
const Rect = @import("paint/Rect.zig");
const Size = @import("paint/Size.zig");
const Point = @import("paint/Point.zig");

const Event = @import("event.zig").Event;

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
};

const WidgetType = enum {
    flex,
    button,

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

    pub fn Type(comptime self: WidgetType) type {
        switch (self) {
            .flex => return @import("widgets/Flex.zig"),
            .button => return @import("widgets/Button.zig"),
        }
    }
};

pub const Layout = struct {
    widgets: std.MultiArrayList(WidgetAttrs) = .{},
    root: WidgetIdx = undefined,
    pointer_position: Point = Point.ZERO,

    pub fn init(self: *Layout, alloc: std.mem.Allocator) !void {
        try self.widgets.ensureTotalCapacity(alloc, 100);
    }
    pub fn add(self: *Layout, widget: WidgetAttrs) WidgetIdx {
        self.widgets.appendAssumeCapacity(widget);
        return @enumFromInt(self.widgets.len - 1);
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
        comptime func: WidgetType.WidgetFn,
        args: anytype,
    ) WidgetType.WidgetFn.ReturnType(func) {
        const t = self.get(idx, .type);

        switch (t) {
            inline else => |wt| {
                const f = @field(wt.Type(), @tagName(func));
                return @call(.auto, f, .{ self, idx } ++ args);
            },
        }
    }

    pub fn request_draw(
        self: *const Layout,
        idx: WidgetIdx,
    ) void {
        self.set(idx, .dirty, true);
        const Window = @import("App.zig").Window;
        const bar = @constCast(@fieldParentPtr(Window, "layout", self));
        bar.schedule_redraw();
    }

    pub fn draw(layout: *Layout, ctx: PaintCtx) void {
        // std.log.info("CALLING DRAW  {}x{}\n", .{ ctx.width, ctx.height });
        // const size = Size.init(ctx.width, ctx.height);
        // _ = size; // autofix
        // const widget_size = layout.get(layout.root, .type).size()(
        //     layout,
        //     layout.root,
        //     Size.Minmax.init(size, size),
        // );
        // const widget_size = layout.call(layout.root, .size, .{
        //     Size.Minmax.init(size, size),
        // });
        layout.widgets.items(.rect)[@intFromEnum(layout.root)] = .{
            .x = 0,
            .y = 0,
            .width = ctx.width,
            .height = ctx.height,
        };

        _ = layout.call(layout.root, .draw, .{ layout.get(layout.root, .rect), ctx });
    }
};
