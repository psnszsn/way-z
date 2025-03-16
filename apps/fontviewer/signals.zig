const W = struct {
    idx: WidgetIdx,
    field: u8,
};

pub fn Signal(T: type) type {
    const t_fields = std.meta.fields(T);
    const S = struct { i: u32 = 0, len: u32 = 0 };
    return struct {
        inner: T,
        layout: *tk.Layout,
        signals: [t_fields.len]S,
        data: std.ArrayListUnmanaged(W) = .{},
        const State = @This();
        pub fn init(layout: *tk.Layout, alloc: std.mem.Allocator) State {
            return .{
                .inner = undefined,
                .layout = layout,
                .signals = .{S{ .i = 0, .len = 0 }} ** t_fields.len,
                .data = std.ArrayListUnmanaged(W).initCapacity(alloc, 10) catch @panic("TODO"),
            };
        }
        pub fn deinit(s: *State, alloc: std.mem.Allocator) void {
            s.data.deinit(alloc);
            s.* = undefined;
        }
        pub fn set_value(s: *State, comptime field: std.meta.FieldEnum(T), value: std.meta.FieldType(T, field)) void {
            @field(s.inner, @tagName(field)) = value;
            const sgnls = s.signals[@intFromEnum(field)];

            for (s.data.items[sgnls.i..][0..sgnls.len]) |w| {
                std.log.info("w={}", .{w});
                s.layout.set_data(w.idx, w.field, @ptrCast(&value));
            }
        }
        pub fn connect(
            s: *State,
            field: std.meta.FieldEnum(T),
            widget_idx: WidgetIdx,
            WidgetData: type,
            widget_field: std.meta.FieldEnum(WidgetData),
        ) void {
            const sgnls = &s.signals[@intFromEnum(field)];
            s.data.insertAssumeCapacity(sgnls.i + sgnls.len, .{
                .idx = widget_idx,
                .field = @intFromEnum(widget_field),
            });
            sgnls.len += 1;
            for (s.signals[@intFromEnum(field) + 1 ..]) |*sgnl| {
                sgnl.i += 1;
            }
        }
    };
}

// const State = struct {
//     selected_range: u32,
//     selected_glyph: u21,
//     font: *const Font,
//     layout: *Layout,
//     singals: [3]W = undefined,
//
//     const W = struct {
//         idx: WidgetIdx,
//         field: u8,
//     };
// };

const std = @import("std");

const tk = @import("toolkit");
const widget = tk.widget;
const WidgetIdx = widget.WidgetIdx;
