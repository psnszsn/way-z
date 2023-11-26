const std = @import("std");
const os = std.os;
const Proxy = @import("../proxy.zig").Proxy;
const Argument = @import("../argument.zig").Argument;
const Fixed = @import("../argument.zig").Fixed;

pub const Display = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Error = enum(c_int) {
        invalid_object = 0,
        invalid_method = 1,
        no_memory = 2,
        implementation = 3,
    };
    pub const Event = union(enum) {
        @"error": struct {
            object_id: ?*anyopaque,
            code: u32,
            message: [*:0]const u8,
        },
        delete_id: struct {
            id: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Display,
        comptime T: type,
        comptime _listener: *const fn (*Display, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Display.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn sync(self: *Display) !*Callback {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Callback, 0, &_args);
    }
    pub fn get_registry(self: *Display) !*Registry {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Registry, 1, &_args);
    }
};
pub const Registry = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Event = union(enum) {
        global: struct {
            name: u32,
            interface: [*:0]const u8,
            version: u32,
        },
        global_remove: struct {
            name: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Registry,
        comptime T: type,
        comptime _listener: *const fn (*Registry, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Registry.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn bind(self: *Registry, _name: u32, comptime T: type) !*T {
        var _args = [_]Argument{
            .{ .uint = _name },
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(T, 0, &_args);
    }
};
pub const Callback = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Event = union(enum) {
        done: struct {
            callback_data: u32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Callback,
        comptime T: type,
        comptime _listener: *const fn (*Callback, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Callback.Event, @ptrCast(_listener), @ptrCast(_data));
    }
};
pub const Compositor = struct {
    proxy: Proxy,
    comptime version: usize = 6,
};
pub const ShmPool = struct {
    proxy: Proxy,
    comptime version: usize = 1,
};
pub const Shm = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Error = enum(c_int) {
        invalid_format = 0,
        invalid_stride = 1,
        invalid_fd = 2,
    };
    pub const Format = enum(c_int) {
        argb8888 = 0,
        xrgb8888 = 1,
        c8 = 538982467,
        rgb332 = 943867730,
        bgr233 = 944916290,
        xrgb4444 = 842093144,
        xbgr4444 = 842089048,
        rgbx4444 = 842094674,
        bgrx4444 = 842094658,
        argb4444 = 842093121,
        abgr4444 = 842089025,
        rgba4444 = 842088786,
        bgra4444 = 842088770,
        xrgb1555 = 892424792,
        xbgr1555 = 892420696,
        rgbx5551 = 892426322,
        bgrx5551 = 892426306,
        argb1555 = 892424769,
        abgr1555 = 892420673,
        rgba5551 = 892420434,
        bgra5551 = 892420418,
        rgb565 = 909199186,
        bgr565 = 909199170,
        rgb888 = 875710290,
        bgr888 = 875710274,
        xbgr8888 = 875709016,
        rgbx8888 = 875714642,
        bgrx8888 = 875714626,
        abgr8888 = 875708993,
        rgba8888 = 875708754,
        bgra8888 = 875708738,
        xrgb2101010 = 808669784,
        xbgr2101010 = 808665688,
        rgbx1010102 = 808671314,
        bgrx1010102 = 808671298,
        argb2101010 = 808669761,
        abgr2101010 = 808665665,
        rgba1010102 = 808665426,
        bgra1010102 = 808665410,
        yuyv = 1448695129,
        yvyu = 1431918169,
        uyvy = 1498831189,
        vyuy = 1498765654,
        ayuv = 1448433985,
        nv12 = 842094158,
        nv21 = 825382478,
        nv16 = 909203022,
        nv61 = 825644622,
        yuv410 = 961959257,
        yvu410 = 961893977,
        yuv411 = 825316697,
        yvu411 = 825316953,
        yuv420 = 842093913,
        yvu420 = 842094169,
        yuv422 = 909202777,
        yvu422 = 909203033,
        yuv444 = 875713881,
        yvu444 = 875714137,
        r8 = 538982482,
        r16 = 540422482,
        rg88 = 943212370,
        gr88 = 943215175,
        rg1616 = 842221394,
        gr1616 = 842224199,
        xrgb16161616f = 1211388504,
        xbgr16161616f = 1211384408,
        argb16161616f = 1211388481,
        abgr16161616f = 1211384385,
        xyuv8888 = 1448434008,
        vuy888 = 875713878,
        vuy101010 = 808670550,
        y210 = 808530521,
        y212 = 842084953,
        y216 = 909193817,
        y410 = 808531033,
        y412 = 842085465,
        y416 = 909194329,
        xvyu2101010 = 808670808,
        xvyu12_16161616 = 909334104,
        xvyu16161616 = 942954072,
        y0l0 = 810299481,
        x0l0 = 810299480,
        y0l2 = 843853913,
        x0l2 = 843853912,
        yuv420_8bit = 942691673,
        yuv420_10bit = 808539481,
        xrgb8888_a8 = 943805016,
        xbgr8888_a8 = 943800920,
        rgbx8888_a8 = 943806546,
        bgrx8888_a8 = 943806530,
        rgb888_a8 = 943798354,
        bgr888_a8 = 943798338,
        rgb565_a8 = 943797586,
        bgr565_a8 = 943797570,
        nv24 = 875714126,
        nv42 = 842290766,
        p210 = 808530512,
        p010 = 808530000,
        p012 = 842084432,
        p016 = 909193296,
        axbxgxrx106106106106 = 808534593,
        nv15 = 892425806,
        q410 = 808531025,
        q401 = 825242705,
        xrgb16161616 = 942953048,
        xbgr16161616 = 942948952,
        argb16161616 = 942953025,
        abgr16161616 = 942948929,
    };
    pub const Event = union(enum) {
        format: struct {
            format: Format,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Shm,
        comptime T: type,
        comptime _listener: *const fn (*Shm, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Shm.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn create_pool(self: *Shm, _fd: i32, _size: i32) !*ShmPool {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .fd = _fd },
            .{ .int = _size },
        };
        return self.proxy.marshal_request_constructor(ShmPool, 0, &_args);
    }
};
pub const Buffer = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Event = union(enum) {
        release: void,
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Buffer,
        comptime T: type,
        comptime _listener: *const fn (*Buffer, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Buffer.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn destroy(self: *Buffer) void {
        self.proxy.marshal(0, null);
        // self.proxy.distroy();
    }
};
pub const DataOffer = struct {
    proxy: Proxy,
    comptime version: usize = 3,
    pub const Error = enum(c_int) {
        invalid_finish = 0,
        invalid_action_mask = 1,
        invalid_action = 2,
        invalid_offer = 3,
    };
    pub const Event = union(enum) {
        offer: struct {
            mime_type: [*:0]const u8,
        },
        source_actions: struct {
            source_actions: DataDeviceManager.DndAction,
        },
        action: struct {
            dnd_action: DataDeviceManager.DndAction,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *DataOffer,
        comptime T: type,
        comptime _listener: *const fn (*DataOffer, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(DataOffer.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn accept(self: *DataOffer, _serial: u32, _mime_type: ?[*:0]const u8) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
            .{ .string = _mime_type },
        };
        self.proxy.marshal(0, &_args);
    }
    pub fn receive(self: *DataOffer, _mime_type: [*:0]const u8, _fd: i32) void {
        var _args = [_]Argument{
            .{ .string = _mime_type },
            .{ .fd = _fd },
        };
        self.proxy.marshal(1, &_args);
    }
    pub fn destroy(self: *DataOffer) void {
        self.proxy.marshal(2, null);
        // self.proxy.distroy();
    }
    pub fn finish(self: *DataOffer) void {
        self.proxy.marshal(3, null);
    }
    pub fn set_actions(self: *DataOffer, _dnd_actions: DataDeviceManager.DndAction, _preferred_action: DataDeviceManager.DndAction) void {
        var _args = [_]Argument{
            .{ .uint = _dnd_actions },
            .{ .uint = _preferred_action },
        };
        self.proxy.marshal(4, &_args);
    }
};
pub const DataSource = struct {
    proxy: Proxy,
    comptime version: usize = 3,
    pub const Error = enum(c_int) {
        invalid_action_mask = 0,
        invalid_source = 1,
    };
    pub const Event = union(enum) {
        target: struct {
            mime_type: ?[*:0]const u8,
        },
        send: struct {
            mime_type: [*:0]const u8,
            fd: i32,
        },
        cancelled: void,
        dnd_drop_performed: void,
        dnd_finished: void,
        action: struct {
            dnd_action: DataDeviceManager.DndAction,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *DataSource,
        comptime T: type,
        comptime _listener: *const fn (*DataSource, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(DataSource.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn offer(self: *DataSource, _mime_type: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _mime_type },
        };
        self.proxy.marshal(0, &_args);
    }
    pub fn destroy(self: *DataSource) void {
        self.proxy.marshal(1, null);
        // self.proxy.distroy();
    }
    pub fn set_actions(self: *DataSource, _dnd_actions: DataDeviceManager.DndAction) void {
        var _args = [_]Argument{
            .{ .uint = _dnd_actions },
        };
        self.proxy.marshal(2, &_args);
    }
};
pub const DataDevice = struct {
    proxy: Proxy,
    comptime version: usize = 3,
    pub const Error = enum(c_int) {
        role = 0,
    };
    pub const Event = union(enum) {
        data_offer: struct { id: *DataOffer },
        enter: struct {
            serial: u32,
            surface: ?*Surface,
            x: Fixed,
            y: Fixed,
            id: ?*DataOffer,
        },
        leave: void,
        motion: struct {
            time: u32,
            x: Fixed,
            y: Fixed,
        },
        drop: void,
        selection: struct {
            id: ?*DataOffer,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *DataDevice,
        comptime T: type,
        comptime _listener: *const fn (*DataDevice, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(DataDevice.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn start_drag(self: *DataDevice, _source: ?*DataSource, _origin: *Surface, _icon: ?*Surface, _serial: u32) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_source) },
            .{ .o = @ptrCast(_origin) },
            .{ .o = @ptrCast(_icon) },
            .{ .uint = _serial },
        };
        self.proxy.marshal(0, &_args);
    }
    pub fn set_selection(self: *DataDevice, _source: ?*DataSource, _serial: u32) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_source) },
            .{ .uint = _serial },
        };
        self.proxy.marshal(1, &_args);
    }
    pub fn release(self: *DataDevice) void {
        self.proxy.marshal(2, null);
        // self.proxy.distroy();
    }
};
pub const DataDeviceManager = struct {
    proxy: Proxy,
    comptime version: usize = 3,
    pub const DndAction = packed struct(u32) {
        copy: bool = false,
        move: bool = false,
        ask: bool = false,
        _padding: u29 = 0,
    };
};
pub const Shell = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Error = enum(c_int) {
        role = 0,
    };
};
pub const ShellSurface = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Resize = packed struct(u32) {
        top: bool = false,
        bottom: bool = false,
        left: bool = false,
        right: bool = false,
        _padding: u28 = 0,
    };
    pub const Transient = packed struct(u32) {
        inactive: bool = false,
        _padding: u31 = 0,
    };
    pub const FullscreenMethod = enum(c_int) {
        default = 0,
        scale = 1,
        driver = 2,
        fill = 3,
    };
    pub const Event = union(enum) {
        ping: struct {
            serial: u32,
        },
        configure: struct {
            edges: Resize,
            width: i32,
            height: i32,
        },
        popup_done: void,
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *ShellSurface,
        comptime T: type,
        comptime _listener: *const fn (*ShellSurface, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(ShellSurface.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn pong(self: *ShellSurface, _serial: u32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
        };
        self.proxy.marshal(0, &_args);
    }
    pub fn move(self: *ShellSurface, _seat: *Seat, _serial: u32) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_seat) },
            .{ .uint = _serial },
        };
        self.proxy.marshal(1, &_args);
    }
    pub fn resize(self: *ShellSurface, _seat: *Seat, _serial: u32, _edges: Resize) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_seat) },
            .{ .uint = _serial },
            .{ .uint = _edges },
        };
        self.proxy.marshal(2, &_args);
    }
    pub fn set_toplevel(self: *ShellSurface) void {
        self.proxy.marshal(3, null);
    }
    pub fn set_transient(self: *ShellSurface, _parent: *Surface, _x: i32, _y: i32, _flags: Transient) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_parent) },
            .{ .int = _x },
            .{ .int = _y },
            .{ .uint = _flags },
        };
        self.proxy.marshal(4, &_args);
    }
    pub fn set_fullscreen(self: *ShellSurface, _method: FullscreenMethod, _framerate: u32, _output: ?*Output) void {
        var _args = [_]Argument{
            .{ .uint = _method },
            .{ .uint = _framerate },
            .{ .o = @ptrCast(_output) },
        };
        self.proxy.marshal(5, &_args);
    }
    pub fn set_popup(self: *ShellSurface, _seat: *Seat, _serial: u32, _parent: *Surface, _x: i32, _y: i32, _flags: Transient) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_seat) },
            .{ .uint = _serial },
            .{ .o = @ptrCast(_parent) },
            .{ .int = _x },
            .{ .int = _y },
            .{ .uint = _flags },
        };
        self.proxy.marshal(6, &_args);
    }
    pub fn set_maximized(self: *ShellSurface, _output: ?*Output) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_output) },
        };
        self.proxy.marshal(7, &_args);
    }
    pub fn set_title(self: *ShellSurface, _title: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _title },
        };
        self.proxy.marshal(8, &_args);
    }
    pub fn set_class(self: *ShellSurface, _class_: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _class_ },
        };
        self.proxy.marshal(9, &_args);
    }
};
pub const Surface = struct {
    proxy: Proxy,
    comptime version: usize = 6,
    pub const Error = enum(c_int) {
        invalid_scale = 0,
        invalid_transform = 1,
        invalid_size = 2,
        invalid_offset = 3,
        defunct_role_object = 4,
    };
    pub const Event = union(enum) {
        enter: struct {
            output: ?*Output,
        },
        leave: struct {
            output: ?*Output,
        },
        preferred_buffer_scale: struct {
            factor: i32,
        },
        preferred_buffer_transform: struct {
            transform: Output.Transform,
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
    pub fn destroy(self: *Surface) void {
        self.proxy.marshal(0, null);
        // self.proxy.distroy();
    }
    pub fn attach(self: *Surface, _buffer: ?*Buffer, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_buffer) },
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal(1, &_args);
    }
    pub fn damage(self: *Surface, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal(2, &_args);
    }
    pub fn frame(self: *Surface) !*Callback {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Callback, 3, &_args);
    }
    pub fn set_opaque_region(self: *Surface, _region: ?*Region) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_region) },
        };
        self.proxy.marshal(4, &_args);
    }
    pub fn set_input_region(self: *Surface, _region: ?*Region) void {
        var _args = [_]Argument{
            .{ .o = @ptrCast(_region) },
        };
        self.proxy.marshal(5, &_args);
    }
    pub fn commit(self: *Surface) void {
        self.proxy.marshal(6, null);
    }
    pub fn set_buffer_transform(self: *Surface, _transform: Output.Transform) void {
        var _args = [_]Argument{
            .{ .int = _transform },
        };
        self.proxy.marshal(7, &_args);
    }
    pub fn set_buffer_scale(self: *Surface, _scale: i32) void {
        var _args = [_]Argument{
            .{ .int = _scale },
        };
        self.proxy.marshal(8, &_args);
    }
    pub fn damage_buffer(self: *Surface, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal(9, &_args);
    }
    pub fn offset(self: *Surface, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal(10, &_args);
    }
};
pub const Seat = struct {
    proxy: Proxy,
    comptime version: usize = 9,
    pub const Capability = packed struct(u32) {
        pointer: bool = false,
        keyboard: bool = false,
        touch: bool = false,
        _padding: u29 = 0,
    };
    pub const Error = enum(c_int) {
        missing_capability = 0,
    };
    pub const Event = union(enum) {
        capabilities: struct {
            capabilities: Capability,
        },
        name: struct {
            name: [*:0]const u8,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Seat,
        comptime T: type,
        comptime _listener: *const fn (*Seat, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Seat.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn get_pointer(self: *Seat) !*Pointer {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Pointer, 0, &_args);
    }
    pub fn get_keyboard(self: *Seat) !*Keyboard {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Keyboard, 1, &_args);
    }
    pub fn get_touch(self: *Seat) !*Touch {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Touch, 2, &_args);
    }
    pub fn release(self: *Seat) void {
        self.proxy.marshal(3, null);
        // self.proxy.distroy();
    }
};
pub const Pointer = struct {
    proxy: Proxy,
    comptime version: usize = 9,
    pub const Error = enum(c_int) {
        role = 0,
    };
    pub const ButtonState = enum(c_int) {
        released = 0,
        pressed = 1,
    };
    pub const Axis = enum(c_int) {
        vertical_scroll = 0,
        horizontal_scroll = 1,
    };
    pub const AxisSource = enum(c_int) {
        wheel = 0,
        finger = 1,
        continuous = 2,
        wheel_tilt = 3,
    };
    pub const AxisRelativeDirection = enum(c_int) {
        identical = 0,
        inverted = 1,
    };
    pub const Event = union(enum) {
        enter: struct {
            serial: u32,
            surface: ?*Surface,
            surface_x: Fixed,
            surface_y: Fixed,
        },
        leave: struct {
            serial: u32,
            surface: ?*Surface,
        },
        motion: struct {
            time: u32,
            surface_x: Fixed,
            surface_y: Fixed,
        },
        button: struct {
            serial: u32,
            time: u32,
            button: u32,
            state: ButtonState,
        },
        axis: struct {
            time: u32,
            axis: Axis,
            value: Fixed,
        },
        frame: void,
        axis_source: struct {
            axis_source: AxisSource,
        },
        axis_stop: struct {
            time: u32,
            axis: Axis,
        },
        axis_discrete: struct {
            axis: Axis,
            discrete: i32,
        },
        axis_value120: struct {
            axis: Axis,
            value120: i32,
        },
        axis_relative_direction: struct {
            axis: Axis,
            direction: AxisRelativeDirection,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Pointer,
        comptime T: type,
        comptime _listener: *const fn (*Pointer, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Pointer.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn set_cursor(self: *Pointer, _serial: u32, _surface: ?*Surface, _hotspot_x: i32, _hotspot_y: i32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
            .{ .o = @ptrCast(_surface) },
            .{ .int = _hotspot_x },
            .{ .int = _hotspot_y },
        };
        self.proxy.marshal(0, &_args);
    }
    pub fn release(self: *Pointer) void {
        self.proxy.marshal(1, null);
        // self.proxy.distroy();
    }
};
pub const Keyboard = struct {
    proxy: Proxy,
    comptime version: usize = 9,
    pub const KeymapFormat = enum(c_int) {
        no_keymap = 0,
        xkb_v1 = 1,
    };
    pub const KeyState = enum(c_int) {
        released = 0,
        pressed = 1,
    };
    pub const Event = union(enum) {
        keymap: struct {
            format: KeymapFormat,
            fd: i32,
            size: u32,
        },
        enter: struct {
            serial: u32,
            surface: ?*Surface,
            keys: *anyopaque,
        },
        leave: struct {
            serial: u32,
            surface: ?*Surface,
        },
        key: struct {
            serial: u32,
            time: u32,
            key: u32,
            state: KeyState,
        },
        modifiers: struct {
            serial: u32,
            mods_depressed: u32,
            mods_latched: u32,
            mods_locked: u32,
            group: u32,
        },
        repeat_info: struct {
            rate: i32,
            delay: i32,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Keyboard,
        comptime T: type,
        comptime _listener: *const fn (*Keyboard, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Keyboard.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn release(self: *Keyboard) void {
        self.proxy.marshal(0, null);
        // self.proxy.distroy();
    }
};
pub const Touch = struct {
    proxy: Proxy,
    comptime version: usize = 9,
    pub const Event = union(enum) {
        down: struct {
            serial: u32,
            time: u32,
            surface: ?*Surface,
            id: i32,
            x: Fixed,
            y: Fixed,
        },
        up: struct {
            serial: u32,
            time: u32,
            id: i32,
        },
        motion: struct {
            time: u32,
            id: i32,
            x: Fixed,
            y: Fixed,
        },
        frame: void,
        cancel: void,
        shape: struct {
            id: i32,
            major: Fixed,
            minor: Fixed,
        },
        orientation: struct {
            id: i32,
            orientation: Fixed,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Touch,
        comptime T: type,
        comptime _listener: *const fn (*Touch, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Touch.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn release(self: *Touch) void {
        self.proxy.marshal(0, null);
        // self.proxy.distroy();
    }
};
pub const Output = struct {
    proxy: Proxy,
    comptime version: usize = 4,
    pub const Subpixel = enum(c_int) {
        unknown = 0,
        none = 1,
        horizontal_rgb = 2,
        horizontal_bgr = 3,
        vertical_rgb = 4,
        vertical_bgr = 5,
    };
    pub const Transform = enum(c_int) {
        normal = 0,
        @"90" = 1,
        @"180" = 2,
        @"270" = 3,
        flipped = 4,
        flipped_90 = 5,
        flipped_180 = 6,
        flipped_270 = 7,
    };
    pub const Mode = packed struct(u32) {
        current: bool = false,
        preferred: bool = false,
        _padding: u30 = 0,
    };
    pub const Event = union(enum) {
        geometry: struct {
            x: i32,
            y: i32,
            physical_width: i32,
            physical_height: i32,
            subpixel: Subpixel,
            make: [*:0]const u8,
            model: [*:0]const u8,
            transform: Transform,
        },
        mode: struct {
            flags: Mode,
            width: i32,
            height: i32,
            refresh: i32,
        },
        done: void,
        scale: struct {
            factor: i32,
        },
        name: struct {
            name: [*:0]const u8,
        },
        description: struct {
            description: [*:0]const u8,
        },
    };
    pub const event_signatures = Proxy.genEventArgs(Event);

    pub inline fn setListener(
        self: *Output,
        comptime T: type,
        comptime _listener: *const fn (*Output, Event, T) void,
        _data: T,
    ) void {
        self.proxy.setListener(Output.Event, @ptrCast(_listener), @ptrCast(_data));
    }
    pub fn release(self: *Output) void {
        self.proxy.marshal(0, null);
        // self.proxy.distroy();
    }
};
pub const Region = struct {
    proxy: Proxy,
    comptime version: usize = 1,
};
pub const Subcompositor = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Error = enum(c_int) {
        bad_surface = 0,
        bad_parent = 1,
    };
};
pub const Subsurface = struct {
    proxy: Proxy,
    comptime version: usize = 1,
    pub const Error = enum(c_int) {
        bad_surface = 0,
    };
};
