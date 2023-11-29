const std = @import("std");
const os = std.os;
const Proxy = @import("../proxy.zig").Proxy;
const Argument = @import("../argument.zig").Argument;
const Fixed = @import("../argument.zig").Fixed;

const wl = @import("wl.zig");
pub const WmBase = struct {
    proxy: Proxy,
    pub const version = 6;
    pub const name = "xdg_wm_base";
    pub const Error = enum(c_int) {
        role = 0,
        defunct_surfaces = 1,
        not_the_topmost_popup = 2,
        invalid_popup_parent = 3,
        invalid_surface_state = 4,
        invalid_positioner = 5,
        unresponsive = 6,
    };
    pub const Event = union(enum) {
        ping: struct {
            serial: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *WmBase,
        comptime T: type,
        comptime _listener: *const fn (*WmBase, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(WmBase.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn destroy(self: *const WmBase) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn create_positioner(self: *const WmBase) !*Positioner {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Positioner, 1, &_args);
    }
    pub fn get_xdg_surface(self: *const WmBase, _surface: *wl.Surface) !*Surface {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .object = _surface.proxy.id },
        };
        return self.proxy.marshal_request_constructor(Surface, 2, &_args);
    }
    pub fn pong(self: *const WmBase, _serial: u32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(3, &_args) catch unreachable;
    }
};
pub const Positioner = struct {
    proxy: Proxy,
    pub const version = 6;
    pub const name = "xdg_positioner";
    pub const Error = enum(c_int) {
        invalid_input = 0,
    };
    pub const Anchor = enum(c_int) {
        none = 0,
        top = 1,
        bottom = 2,
        left = 3,
        right = 4,
        top_left = 5,
        bottom_left = 6,
        top_right = 7,
        bottom_right = 8,
    };
    pub const Gravity = enum(c_int) {
        none = 0,
        top = 1,
        bottom = 2,
        left = 3,
        right = 4,
        top_left = 5,
        bottom_left = 6,
        top_right = 7,
        bottom_right = 8,
    };
    pub const ConstraintAdjustment = packed struct(u32) {
        slide_x: bool = false,
        slide_y: bool = false,
        flip_x: bool = false,
        flip_y: bool = false,
        resize_x: bool = false,
        resize_y: bool = false,
        _padding: u26 = 0,
    };
    pub fn destroy(self: *const Positioner) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn set_size(self: *const Positioner, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn set_anchor_rect(self: *const Positioner, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
    pub fn set_anchor(self: *const Positioner, _anchor: Anchor) void {
        var _args = [_]Argument{
            .{ .uint = @intCast(@intFromEnum(_anchor)) },
        };
        self.proxy.marshal_request(3, &_args) catch unreachable;
    }
    pub fn set_gravity(self: *const Positioner, _gravity: Gravity) void {
        var _args = [_]Argument{
            .{ .uint = @intCast(@intFromEnum(_gravity)) },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
    pub fn set_constraint_adjustment(self: *const Positioner, _constraint_adjustment: u32) void {
        var _args = [_]Argument{
            .{ .uint = _constraint_adjustment },
        };
        self.proxy.marshal_request(5, &_args) catch unreachable;
    }
    pub fn set_offset(self: *const Positioner, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal_request(6, &_args) catch unreachable;
    }
    pub fn set_reactive(self: *const Positioner) void {
        self.proxy.marshal_request(7, &.{}) catch unreachable;
    }
    pub fn set_parent_size(self: *const Positioner, _parent_width: i32, _parent_height: i32) void {
        var _args = [_]Argument{
            .{ .int = _parent_width },
            .{ .int = _parent_height },
        };
        self.proxy.marshal_request(8, &_args) catch unreachable;
    }
    pub fn set_parent_configure(self: *const Positioner, _serial: u32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(9, &_args) catch unreachable;
    }
};
pub const Surface = struct {
    proxy: Proxy,
    pub const version = 6;
    pub const name = "xdg_surface";
    pub const Error = enum(c_int) {
        not_constructed = 1,
        already_constructed = 2,
        unconfigured_buffer = 3,
        invalid_serial = 4,
        invalid_size = 5,
        defunct_role_object = 6,
    };
    pub const Event = union(enum) {
        configure: struct {
            serial: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Surface,
        comptime T: type,
        comptime _listener: *const fn (*Surface, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Surface.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn destroy(self: *const Surface) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn get_toplevel(self: *const Surface) !*Toplevel {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Toplevel, 1, &_args);
    }
    pub fn get_popup(self: *const Surface, _parent: ?*Surface, _positioner: *Positioner) !*Popup {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .object = if (_parent) |arg| arg.proxy.id else 0 },
            .{ .object = _positioner.proxy.id },
        };
        return self.proxy.marshal_request_constructor(Popup, 2, &_args);
    }
    pub fn set_window_geometry(self: *const Surface, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(3, &_args) catch unreachable;
    }
    pub fn ack_configure(self: *const Surface, _serial: u32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
};
pub const Toplevel = struct {
    proxy: Proxy,
    pub const version = 6;
    pub const name = "xdg_toplevel";
    pub const Error = enum(c_int) {
        invalid_resize_edge = 0,
        invalid_parent = 1,
        invalid_size = 2,
    };
    pub const ResizeEdge = enum(c_int) {
        none = 0,
        top = 1,
        bottom = 2,
        left = 4,
        top_left = 5,
        bottom_left = 6,
        right = 8,
        top_right = 9,
        bottom_right = 10,
    };
    pub const State = enum(c_int) {
        maximized = 1,
        fullscreen = 2,
        resizing = 3,
        activated = 4,
        tiled_left = 5,
        tiled_right = 6,
        tiled_top = 7,
        tiled_bottom = 8,
        suspended = 9,
    };
    pub const WmCapabilities = enum(c_int) {
        window_menu = 1,
        maximize = 2,
        fullscreen = 3,
        minimize = 4,
    };
    pub const Event = union(enum) {
        configure: struct {
            width: i32,
            height: i32,
            states: *anyopaque,
        },
        close: void,
        configure_bounds: struct {
            width: i32,
            height: i32,
        },
        wm_capabilities: struct {
            capabilities: *anyopaque,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Toplevel,
        comptime T: type,
        comptime _listener: *const fn (*Toplevel, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Toplevel.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn destroy(self: *const Toplevel) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn set_parent(self: *const Toplevel, _parent: ?*Toplevel) void {
        var _args = [_]Argument{
            .{ .object = if (_parent) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn set_title(self: *const Toplevel, _title: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _title },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
    pub fn set_app_id(self: *const Toplevel, _app_id: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _app_id },
        };
        self.proxy.marshal_request(3, &_args) catch unreachable;
    }
    pub fn show_window_menu(self: *const Toplevel, _seat: *wl.Seat, _serial: u32, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
    pub fn move(self: *const Toplevel, _seat: *wl.Seat, _serial: u32) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(5, &_args) catch unreachable;
    }
    pub fn resize(self: *const Toplevel, _seat: *wl.Seat, _serial: u32, _edges: ResizeEdge) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
            .{ .uint = @intCast(@intFromEnum(_edges)) },
        };
        self.proxy.marshal_request(6, &_args) catch unreachable;
    }
    pub fn set_max_size(self: *const Toplevel, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(7, &_args) catch unreachable;
    }
    pub fn set_min_size(self: *const Toplevel, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(8, &_args) catch unreachable;
    }
    pub fn set_maximized(self: *const Toplevel) void {
        self.proxy.marshal_request(9, &.{}) catch unreachable;
    }
    pub fn unset_maximized(self: *const Toplevel) void {
        self.proxy.marshal_request(10, &.{}) catch unreachable;
    }
    pub fn set_fullscreen(self: *const Toplevel, _output: ?*wl.Output) void {
        var _args = [_]Argument{
            .{ .object = if (_output) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(11, &_args) catch unreachable;
    }
    pub fn unset_fullscreen(self: *const Toplevel) void {
        self.proxy.marshal_request(12, &.{}) catch unreachable;
    }
    pub fn set_minimized(self: *const Toplevel) void {
        self.proxy.marshal_request(13, &.{}) catch unreachable;
    }
};
pub const Popup = struct {
    proxy: Proxy,
    pub const version = 6;
    pub const name = "xdg_popup";
    pub const Error = enum(c_int) {
        invalid_grab = 0,
    };
    pub const Event = union(enum) {
        configure: struct {
            x: i32,
            y: i32,
            width: i32,
            height: i32,
        },
        popup_done: void,
        repositioned: struct {
            token: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Popup,
        comptime T: type,
        comptime _listener: *const fn (*Popup, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Popup.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn destroy(self: *const Popup) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn grab(self: *const Popup, _seat: *wl.Seat, _serial: u32) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn reposition(self: *const Popup, _positioner: *Positioner, _token: u32) void {
        var _args = [_]Argument{
            .{ .object = _positioner.proxy.id },
            .{ .uint = _token },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
};
