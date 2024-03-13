const Point = @import("paint/Point.zig");
const wl = @import("wayland").wl;

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

pub const PointerEvent = union(enum) {
    enter: void,
    leave: void,
    motion: Point,
    button: struct {
        button: MouseButton, // button that produced the event
        state: wl.Pointer.ButtonState, // physical state of the button

    },
};
