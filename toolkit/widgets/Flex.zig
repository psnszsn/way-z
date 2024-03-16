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

orientation: Orientation,

var g = Flex{
    .orientation = .horizontal,
};

const Orientation = enum {
    vertical,
    horizontal,

    pub fn majorLen(self: Orientation, s: Size) usize {
        switch (self) {
            .horizontal => return s.width,
            .vertical => return s.height,
        }
    }
    pub fn minorLen(self: Orientation, s: Size) usize {
        switch (self) {
            .horizontal => return s.height,
            .vertical => return s.width,
        }
    }

    pub fn pack(self: Orientation, major: usize, minor: usize) Point {
        switch (self) {
            .horizontal => return Point{ .x = major, .y = minor },
            .vertical => return Point{ .x = minor, .y = major },
        }
    }

    pub fn majorSize(self: Orientation, major: usize, minor: usize) Size {
        switch (self) {
            .horizontal => return Size{ .width = major, .height = minor },
            .vertical => return Size{ .width = minor, .height = major },
        }
    }
    pub fn constraints(
        self: Orientation,
        mm: Size.Minmax,
        min_major: usize,
        major: usize,
    ) Size.Minmax {
        switch (self) {
            .horizontal => return Size.Minmax{
                .min = Size{
                    .width = min_major,
                    .height = mm.min.height,
                },
                .max = Size{
                    .width = major,
                    .height = mm.max.height,
                },
            },
            .vertical => return Size.Minmax{
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

// pub const Spacer = struct {
//     widget: *Widget,
//     pub fn draw(_: *Spacer, _: waq.Painter) bool {
//         return true;
//     }
//     pub fn size(_: *Spacer, constraints: Size.Minmax) Size {
//         return constraints.max;
//     }
// };

pub fn size(layout: *Layout, idx: WidgetIdx, constraints: Size.Minmax) Size {
    const children = layout.get(idx, .children);
    const self = g;
    var minor: usize = self.orientation.minorLen(constraints.min);

    var non_flex_major_sum: usize = 0;
    var flex_factor_sum: usize = 0;

    // Measure non-flex children
    for (children) |child_idx| {
        const child_flex = layout.get(child_idx, .flex);
        if (child_flex == 0) {
            const child_size = layout.call(child_idx, .size, .{Size.Minmax.loose(constraints.max)});
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

    if (flex_factor_sum == 0) {
        return self.orientation.majorSize(
            @max(non_flex_major_sum, min_buffer_size_major),
            minor,
        );
    }

    const remaining = max_buffer_size_major -| non_flex_major_sum;
    const px_per_flex = remaining / flex_factor_sum;

    // Measure flex children
    for (children) |child_idx| {
        const child_flex = layout.get(child_idx, .flex);
        if (child_flex > 0) {
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

    var major: usize = 0;
    for (children) |child_idx| {
        const origin_point = self.orientation.pack(major, 0);
        var rect = layout.get(child_idx, .rect);
        rect.setOrigin(origin_point);
        layout.set(child_idx, .rect, rect);
        major += self.orientation.majorLen(rect.getSize());
    }

    return self.orientation.majorSize(major, minor);
}

pub fn draw(layout: *Layout, idx: WidgetIdx, _: Rect, ctx: PaintCtx) bool {
    const children = layout.get(idx, .children);
    for (children) |child_idx| {
        const r = layout.get(child_idx, .rect);
        _ = layout.call(child_idx, .draw, .{ r, ctx });
    }
    return true;
}

pub fn handle_event(layout: *Layout, idx: WidgetIdx, _event: Event) void {
    _ = idx; // autofix
    _ = layout; // autofix
    switch (_event) {
        .pointer => |event| {
            _ = event; // autofix
        },
    }
}
