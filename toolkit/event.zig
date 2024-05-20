const Point = @import("paint/Point.zig");
const wl = @import("wayland").wl;
const WidgetIdx = @import("widget.zig").WidgetIdx;

pub const Event = union(enum) {
    pointer: PointerEvent,
    custom: struct {
        emitter: WidgetIdx,
        data: [4]u8,
    },
    command: struct {
        num: u32,
        data: [4]u8,
    },

    pub const PointerEvent = union(enum) {
        enter: void,
        leave: void,
        motion: Point,
        axis: struct {
            value: i32,
        },
        button: struct {
            button: MouseButton, // button that produced the event
            state: wl.Pointer.ButtonState, // physical state of the button

        },
    };
};

pub const MouseButton = enum(u32) {
    LEFT = 0x110,
    RIGHT = 0x111,
    MIDDLE = 0x112,
    SIDE = 0x113,
    EXTRA = 0x114,
    FORWARD = 0x115,
    BACK = 0x116,
    TASK = 0x117,
};
