const Flex = @This();
const std = @import("std");

const PaintCtx = @import("../paint.zig").PaintCtxU32;
const Event = @import("../event.zig").Event;
const Rect = @import("../paint/Rect.zig");
const Size = @import("../paint/Size.zig");
const Point = @import("../paint/Point.zig");

const w = @import("../widget.zig");
const Layout = w.Layout;
const WidgetIdx = w.WidgetIdx;

// const waq = @import("../lib.zig");
// const Widget = waq.Widget;
// const Point = waq.Point;
// const Color = waq.Color;
// const Size = waq.Size;
// const Rect = waq.Rect;
// const util = waq.util;
// var allocator = util.allocator;
//
// const FlexChild = struct {
//     widget: *Widget,
//     name: []const u8,
//     rect: Rect,
//     flex: usize = 0,
// };
//
// widget: *Widget,
// children: std.ArrayList(FlexChild),
// active_child: ?*FlexChild = null,
// focuse_child: ?*FlexChild = null,
// hovered_child: ?*FlexChild = null,
//
orientation: Orientation,

var g = Flex{
    .orientation = .Vertical,
};

const Orientation = enum {
    Vertical,
    Horizontal,

    pub fn majorLen(self: Orientation, s: Size) usize {
        switch (self) {
            .Horizontal => return s.width,
            .Vertical => return s.height,
        }
    }
    pub fn minorLen(self: Orientation, s: Size) usize {
        switch (self) {
            .Horizontal => return s.height,
            .Vertical => return s.width,
        }
    }

    pub fn pack(self: Orientation, major: usize, minor: usize) Point {
        switch (self) {
            .Horizontal => return Point{ .x = major, .y = minor },
            .Vertical => return Point{ .x = minor, .y = major },
        }
    }

    pub fn majorSize(self: Orientation, major: usize, minor: usize) Size {
        switch (self) {
            .Horizontal => return Size{ .width = major, .height = minor },
            .Vertical => return Size{ .width = minor, .height = major },
        }
    }
    pub fn constraints(
        self: Orientation,
        mm: Size.Minmax,
        min_major: usize,
        major: usize,
    ) Size.Minmax {
        switch (self) {
            .Horizontal => return Size.Minmax{
                .min = Size{
                    .width = min_major,
                    .height = mm.min.height,
                },
                .max = Size{
                    .width = major,
                    .height = mm.max.height,
                },
            },
            .Vertical => return Size.Minmax{
                .min = Size{
                    .width = mm.min.width,
                    .height = min_major,
                },
                .max = Size{
                    .width = mm.max.width,
                    .height = major,
                },
            },
        }
    }
};
//
// pub const Spacer = struct {
//     widget: *Widget,
//     pub fn draw(_: *Spacer, _: waq.Painter) bool {
//         return true;
//     }
//     pub fn size(_: *Spacer, constraints: Size.Minmax) Size {
//         return constraints.max;
//     }
//     pub fn init(app: *waq.App) !*Spacer {
//         const self = try app.allocator.create(Spacer);
//         self.* = .{
//             .widget = try Widget.init(app, self),
//         };
//         return self;
//     }
//     pub fn deinit(self: *Spacer) void {
//         _ = self;
//         // TODO
//     }
// };
//
//
pub fn size(layout: *Layout, idx: WidgetIdx, constraints: Size.Minmax) Size {
    // std.log.info("CALLING SIZE\n", .{});
    const self = g;
    var minor: usize = self.orientation.minorLen(constraints.min);

    var non_flex_major_sum: usize = 0;
    var flex_factor_sum: usize = 0;

    const children = layout.get(idx, .children);
    // std.log.info("children {any}", .{children});
    // Measure non-flex children
    for (children) |child_idx| {
        const child_flex = layout.get(child_idx, .flex);
        if (child_flex == 0) {
            const child_size = layout.call(child_idx, .size, .{Size.Minmax.loose(constraints.max)});
            // child.rect.setSize(child_size);
            const origin = self.orientation.pack(non_flex_major_sum, 0);
            layout.set(child_idx, .rect, Rect{
                .x = origin.x,
                .y = origin.y,
                .width = child_size.width,
                .height = child_size.height,
            });
            non_flex_major_sum += self.orientation.majorLen(child_size);
            minor = @max(minor, self.orientation.minorLen(child_size));
        } else {
            flex_factor_sum += child_flex;
        }
    }

    // Early return if there are no flex children
    const max_buffer_size_major = self.orientation.majorLen(constraints.max);
    const min_buffer_size_major = self.orientation.majorLen(constraints.min);
    _ = min_buffer_size_major; // autofix
    // std.debug.print("constraints: {} {}\n", .{
    //     @max(non_flex_major_sum, min_buffer_size_major),
    //     minor,
    // });
    // std.debug.print("asd {s}\n", .{self.children.items});

    if (flex_factor_sum != 0) {
        const remaining = max_buffer_size_major -| non_flex_major_sum;
        const px_per_flex = remaining / flex_factor_sum;

        // Measure flex children
        for (children) |child_idx| {
            const child_flex = layout.get(child_idx, .flex);
            if (child_flex > 0) {
                // const child_mm = self.orientation.constraints(constraints.loose(), 0, px_per_flex);
                const child_max = self.orientation.majorSize(
                    px_per_flex * child_flex,
                    self.orientation.minorLen(constraints.min),
                );
                const child_min = layout.call(child_idx, .size, .{Size.Minmax.ZERO});

                layout.set(child_idx, .rect, .{
                    .width = @max(child_min.width, child_max.width),
                    .height = @max(child_min.height, child_max.height),
                });
            }
        }
    }
    // if (non_flex_major_sum >= max_buffer_size_major or flex_factor_sum == 0) {
    //     return self.orientation.majorSize(
    //         @max(non_flex_major_sum, min_buffer_size_major),
    //         minor,
    //     );
    // }

    // std.debug.print("constraints: {s}\n", .{constraints});
    var major: usize = 0;
    for (children) |child_idx| {
        const origin_point = self.orientation.pack(major, 0);
        var rect = layout.get(child_idx, .rect);
        rect.setOrigin(origin_point);
        layout.set(child_idx, .rect, rect);
        major += self.orientation.majorLen(rect.getSize());
        // std.debug.print("size child: {s}\n", .{child.rect});
    }

    // std.debug.print("constraints: {} {}\n", .{ major, minor });

    std.log.info("ZZZZZZZZ {}", .{self.orientation.majorSize(major, minor)});
    return self.orientation.majorSize(major, minor);
}

pub fn draw(layout: *Layout, idx: WidgetIdx, _: Rect, ctx: PaintCtx) bool {
    const children = layout.get(idx, .children);
    for (children) |child_idx| {
        const r = layout.get(child_idx, .rect);
        // std.log.info("child rect {}", .{r});

        _ = layout.call(child_idx, .draw, .{ r, ctx });
    }
    // _ = child.widget.draw(painter.buffer, child.rect.translated(painter.clip.getPosition()));
    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, _event: Event) void {
    _ = idx; // autofix
    _ = layout; // autofix
    // std.log.info("handle_event {}", .{idx});
    switch (_event) {
        .pointer => |event| {
            _ = event; // autofix
        },
    }
    // if (event.state == .leave) {
    //     self.setHoveredChild(null);
    // }
    //
    // if (self.active_child) |child| {
    //     child.widget.click(event);
    //     if (event.state == .released) {
    //         self.active_child = null;
    //     }
    //     // TODO: Fix this
    // } else if (self.childAtPos(event.position)) |child| {
    //     switch (event.state) {
    //         .pressed => {
    //             self.active_child = child;
    //         },
    //         .none, .enter => {
    //             self.setHoveredChild(child);
    //         },
    //         else => {},
    //     }
    //     child.widget.click(event.relativeTo(child.rect.getPosition()));
    //     // child.widget.click(event);
    // } else {
    //     self.setHoveredChild(null);
    // }
}

//
// pub fn setHoveredChild(self: *Self, child: ?*FlexChild) void {
//     if (self.hovered_child == child) return;
//     // std.debug.print("old: {s}\n", .{self.hovered_child});
//     // std.debug.print("new: {s}\n\n\n", .{child});
//
//     if (self.hovered_child) |current| {
//         current.widget.click(.{
//             .position = Point.ZERO,
//             .state = .leave,
//         });
//     }
//
//     if (child) |c| {
//         self.hovered_child = child;
//         c.widget.click(.{
//             .position = Point.ZERO,
//             .state = .enter,
//         });
//     } else {
//         self.hovered_child = null;
//     }
// }
//
// pub fn childAtPos(self: *const Self, position: Point) ?*FlexChild {
//     for (self.children.items) |*child| {
//         if (child.rect.contains(position)) {
//             // std.debug.print("clicked child {} \n", .{i});
//             return child;
//         }
//     }
//     return null;
// }
//
// pub fn addChild(self: *Self, child: *Widget, name: []const u8) !void {
//     const c = FlexChild{
//         .widget = child,
//         .name = name,
//         .rect = Rect.ZERO,
//     };
//     try self.children.append(c);
// }
//
// pub fn findChildOfType(self: *Self, comptime WidgetType: type, name: []const u8) ?*WidgetType {
//     for (self.children.items) |*curr_child| {
//         if (std.mem.eql(u8, curr_child.name, name)) {
//             const w = curr_child.widget.as(WidgetType);
//             return w;
//         }
//         if (std.mem.eql(u8, curr_child.widget.t, @typeName(Self))) {
//             const f = curr_child.widget.as(Self);
//             if (f.findChildOfType(WidgetType, name)) |widget| {
//                 return widget;
//             }
//         }
//     }
//     return null;
// }
//
// pub fn getChildRectTrace(self: *Self, child: *Widget) !std.ArrayList(*Rect) {
//     for (self.children.items) |*curr_child| {
//         if (std.mem.eql(u8, curr_child.widget.t, @typeName(Self))) {
//             const f = curr_child.widget.as(Self);
//             var r = (f.getChildRectTrace(child) catch unreachable);
//             if (r.items.len > 0) {
//                 try r.append(&curr_child.rect);
//                 return r;
//             } else {
//                 r.deinit();
//             }
//         }
//         if (curr_child.widget.impl == child.impl) {
//             var rects = std.ArrayList(*Rect).init(self.widget.app.allocator);
//             try rects.append(&curr_child.rect);
//             return rects;
//         }
//     }
//     return std.ArrayList(*Rect).init(self.widget.app.allocator);
// }
//
