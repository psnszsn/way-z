const std = @import("std");
const os = std.os;
const Proxy = @import("../proxy.zig").Proxy;
const Interface = @import("../proxy.zig").Interface;
const Argument = @import("../argument.zig").Argument;
const Fixed = @import("../argument.zig").Fixed;

pub const Display = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_display",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "error",
            "delete_id",
        },
        .request_names = &.{
            "sync",
            "get_registry",
        },
    };
    pub const Error = enum(c_int) {
        invalid_object = 0,
        invalid_method = 1,
        no_memory = 2,
        implementation = 3,
    };
    pub const Event = union(enum) {
        @"error": struct {
            object_id: ?u32,
            code: u32,
            message: [*:0]const u8,
        },
        delete_id: struct {
            id: u32,
        },
    };

    pub inline fn set_listener(
        self: *Display,
        comptime T: type,
        comptime _listener: *const fn (*Display, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .@"error" = .{
                        .object_id = args[0].object,
                        .code = args[1].uint,
                        .message = args[2].string,
                    } },
                    1 => Event{ .delete_id = .{
                        .id = args[0].uint,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Display, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn sync(self: *const Display) !*Callback {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Callback, 0, &_args);
    }
    pub fn get_registry(self: *const Display) !*Registry {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Registry, 1, &_args);
    }
};
pub const Registry = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_registry",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "global",
            "global_remove",
        },
        .request_names = &.{
            "bind",
        },
    };
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

    pub inline fn set_listener(
        self: *Registry,
        comptime T: type,
        comptime _listener: *const fn (*Registry, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .global = .{
                        .name = args[0].uint,
                        .interface = args[1].string,
                        .version = args[2].uint,
                    } },
                    1 => Event{ .global_remove = .{
                        .name = args[0].uint,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Registry, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn bind(self: *const Registry, _name: u32, comptime T: type, _version: u32) !*T {
        var _args = [_]Argument{
            .{ .uint = _name },
            .{ .string = T.interface.name },
            .{ .uint = _version },
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(T, 0, &_args);
    }
};
pub const Callback = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_callback",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "done",
        },
    };
    pub const Event = union(enum) {
        done: struct {
            callback_data: u32,
        },
    };

    pub inline fn set_listener(
        self: *Callback,
        comptime T: type,
        comptime _listener: *const fn (*Callback, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .done = .{
                        .callback_data = args[0].uint,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Callback, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
};
pub const Compositor = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_compositor",
        .version = 6,
        .request_names = &.{
            "create_surface",
            "create_region",
        },
    };
    pub fn create_surface(self: *const Compositor) !*Surface {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Surface, 0, &_args);
    }
    pub fn create_region(self: *const Compositor) !*Region {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Region, 1, &_args);
    }
};
pub const ShmPool = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_shm_pool",
        .version = 1,
        .request_names = &.{
            "create_buffer",
            "destroy",
            "resize",
        },
    };
    pub fn create_buffer(self: *const ShmPool, _offset: i32, _width: i32, _height: i32, _stride: i32, _format: Shm.Format) !*Buffer {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .int = _offset },
            .{ .int = _width },
            .{ .int = _height },
            .{ .int = _stride },
            .{ .uint = @intCast(@intFromEnum(_format)) },
        };
        return self.proxy.marshal_request_constructor(Buffer, 0, &_args);
    }
    pub fn destroy(self: *const ShmPool) void {
        self.proxy.marshal_request(1, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn resize(self: *const ShmPool, _size: i32) void {
        var _args = [_]Argument{
            .{ .int = _size },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
};
pub const Shm = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_shm",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "format",
        },
        .request_names = &.{
            "create_pool",
        },
    };
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

    pub inline fn set_listener(
        self: *Shm,
        comptime T: type,
        comptime _listener: *const fn (*Shm, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .format = .{
                        .format = @bitCast(args[0].uint),
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Shm, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn create_pool(self: *const Shm, _fd: i32, _size: i32) !*ShmPool {
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
    pub const interface = Interface{
        .name = "wl_buffer",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "release",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        release: void,
    };

    pub inline fn set_listener(
        self: *Buffer,
        comptime T: type,
        comptime _listener: *const fn (*Buffer, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event.release,
                    else => unreachable,
                };
                _ = args;
                @call(.always_inline, _listener, .{
                    @as(*Buffer, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn destroy(self: *const Buffer) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const DataOffer = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_data_offer",
        .version = 3,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "offer",
            "source_actions",
            "action",
        },
        .request_names = &.{
            "accept",
            "receive",
            "destroy",
            "finish",
            "set_actions",
        },
    };
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

    pub inline fn set_listener(
        self: *DataOffer,
        comptime T: type,
        comptime _listener: *const fn (*DataOffer, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .offer = .{
                        .mime_type = args[0].string,
                    } },
                    1 => Event{ .source_actions = .{
                        .source_actions = @bitCast(args[0].uint),
                    } },
                    2 => Event{ .action = .{
                        .dnd_action = @bitCast(args[0].uint),
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*DataOffer, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn accept(self: *const DataOffer, _serial: u32, _mime_type: ?[*:0]const u8) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
            .{ .string = _mime_type },
        };
        self.proxy.marshal_request(0, &_args) catch unreachable;
    }
    pub fn receive(self: *const DataOffer, _mime_type: [*:0]const u8, _fd: i32) void {
        var _args = [_]Argument{
            .{ .string = _mime_type },
            .{ .fd = _fd },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn destroy(self: *const DataOffer) void {
        self.proxy.marshal_request(2, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn finish(self: *const DataOffer) void {
        self.proxy.marshal_request(3, &.{}) catch unreachable;
    }
    pub fn set_actions(self: *const DataOffer, _dnd_actions: DataDeviceManager.DndAction, _preferred_action: DataDeviceManager.DndAction) void {
        var _args = [_]Argument{
            .{ .uint = @intCast(@intFromEnum(_dnd_actions)) },
            .{ .uint = @intCast(@intFromEnum(_preferred_action)) },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
};
pub const DataSource = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_data_source",
        .version = 3,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "target",
            "send",
            "cancelled",
            "dnd_drop_performed",
            "dnd_finished",
            "action",
        },
        .request_names = &.{
            "offer",
            "destroy",
            "set_actions",
        },
    };
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

    pub inline fn set_listener(
        self: *DataSource,
        comptime T: type,
        comptime _listener: *const fn (*DataSource, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .target = .{
                        .mime_type = args[0].string,
                    } },
                    1 => Event{ .send = .{
                        .mime_type = args[0].string,
                        .fd = args[1].fd,
                    } },
                    2 => Event.cancelled,
                    3 => Event.dnd_drop_performed,
                    4 => Event.dnd_finished,
                    5 => Event{ .action = .{
                        .dnd_action = @bitCast(args[0].uint),
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*DataSource, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn offer(self: *const DataSource, _mime_type: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _mime_type },
        };
        self.proxy.marshal_request(0, &_args) catch unreachable;
    }
    pub fn destroy(self: *const DataSource) void {
        self.proxy.marshal_request(1, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn set_actions(self: *const DataSource, _dnd_actions: DataDeviceManager.DndAction) void {
        var _args = [_]Argument{
            .{ .uint = @intCast(@intFromEnum(_dnd_actions)) },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
};
pub const DataDevice = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_data_device",
        .version = 3,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "data_offer",
            "enter",
            "leave",
            "motion",
            "drop",
            "selection",
        },
        .request_names = &.{
            "start_drag",
            "set_selection",
            "release",
        },
    };
    pub const Error = enum(c_int) {
        role = 0,
    };
    pub const Event = union(enum) {
        data_offer: struct { id: *DataOffer },
        enter: struct {
            serial: u32,
            surface: ?u32,
            x: Fixed,
            y: Fixed,
            id: u32,
        },
        leave: void,
        motion: struct {
            time: u32,
            x: Fixed,
            y: Fixed,
        },
        drop: void,
        selection: struct {
            id: u32,
        },
    };

    pub inline fn set_listener(
        self: *DataDevice,
        comptime T: type,
        comptime _listener: *const fn (*DataDevice, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .data_offer = .{
                        .id = args[0].new_id,
                    } },
                    1 => Event{ .enter = .{
                        .serial = args[0].uint,
                        .surface = args[1].object,
                        .x = args[2].fixed,
                        .y = args[3].fixed,
                        .id = args[4].object,
                    } },
                    2 => Event.leave,
                    3 => Event{ .motion = .{
                        .time = args[0].uint,
                        .x = args[1].fixed,
                        .y = args[2].fixed,
                    } },
                    4 => Event.drop,
                    5 => Event{ .selection = .{
                        .id = args[0].object,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*DataDevice, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn start_drag(self: *const DataDevice, _source: ?*DataSource, _origin: *Surface, _icon: ?*Surface, _serial: u32) void {
        var _args = [_]Argument{
            .{ .object = if (_source) |arg| arg.proxy.id else 0 },
            .{ .object = _origin.proxy.id },
            .{ .object = if (_icon) |arg| arg.proxy.id else 0 },
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(0, &_args) catch unreachable;
    }
    pub fn set_selection(self: *const DataDevice, _source: ?*DataSource, _serial: u32) void {
        var _args = [_]Argument{
            .{ .object = if (_source) |arg| arg.proxy.id else 0 },
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn release(self: *const DataDevice) void {
        self.proxy.marshal_request(2, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const DataDeviceManager = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_data_device_manager",
        .version = 3,
        .request_names = &.{
            "create_data_source",
            "get_data_device",
        },
    };
    pub const DndAction = packed struct(u32) {
        copy: bool = false,
        move: bool = false,
        ask: bool = false,
        _padding: u29 = 0,
    };
    pub fn create_data_source(self: *const DataDeviceManager) !*DataSource {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(DataSource, 0, &_args);
    }
    pub fn get_data_device(self: *const DataDeviceManager, _seat: *Seat) !*DataDevice {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .object = _seat.proxy.id },
        };
        return self.proxy.marshal_request_constructor(DataDevice, 1, &_args);
    }
};
pub const Shell = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_shell",
        .version = 1,
        .request_names = &.{
            "get_shell_surface",
        },
    };
    pub const Error = enum(c_int) {
        role = 0,
    };
    pub fn get_shell_surface(self: *const Shell, _surface: *Surface) !*ShellSurface {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .object = _surface.proxy.id },
        };
        return self.proxy.marshal_request_constructor(ShellSurface, 0, &_args);
    }
};
pub const ShellSurface = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_shell_surface",
        .version = 1,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "ping",
            "configure",
            "popup_done",
        },
        .request_names = &.{
            "pong",
            "move",
            "resize",
            "set_toplevel",
            "set_transient",
            "set_fullscreen",
            "set_popup",
            "set_maximized",
            "set_title",
            "set_class",
        },
    };
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

    pub inline fn set_listener(
        self: *ShellSurface,
        comptime T: type,
        comptime _listener: *const fn (*ShellSurface, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .ping = .{
                        .serial = args[0].uint,
                    } },
                    1 => Event{ .configure = .{
                        .edges = @bitCast(args[0].uint),
                        .width = args[1].int,
                        .height = args[2].int,
                    } },
                    2 => Event.popup_done,
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*ShellSurface, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn pong(self: *const ShellSurface, _serial: u32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(0, &_args) catch unreachable;
    }
    pub fn move(self: *const ShellSurface, _seat: *Seat, _serial: u32) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn resize(self: *const ShellSurface, _seat: *Seat, _serial: u32, _edges: Resize) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
            .{ .uint = @intCast(@intFromEnum(_edges)) },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
    pub fn set_toplevel(self: *const ShellSurface) void {
        self.proxy.marshal_request(3, &.{}) catch unreachable;
    }
    pub fn set_transient(self: *const ShellSurface, _parent: *Surface, _x: i32, _y: i32, _flags: Transient) void {
        var _args = [_]Argument{
            .{ .object = _parent.proxy.id },
            .{ .int = _x },
            .{ .int = _y },
            .{ .uint = @intCast(@intFromEnum(_flags)) },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
    pub fn set_fullscreen(self: *const ShellSurface, _method: FullscreenMethod, _framerate: u32, _output: ?*Output) void {
        var _args = [_]Argument{
            .{ .uint = @intCast(@intFromEnum(_method)) },
            .{ .uint = _framerate },
            .{ .object = if (_output) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(5, &_args) catch unreachable;
    }
    pub fn set_popup(self: *const ShellSurface, _seat: *Seat, _serial: u32, _parent: *Surface, _x: i32, _y: i32, _flags: Transient) void {
        var _args = [_]Argument{
            .{ .object = _seat.proxy.id },
            .{ .uint = _serial },
            .{ .object = _parent.proxy.id },
            .{ .int = _x },
            .{ .int = _y },
            .{ .uint = @intCast(@intFromEnum(_flags)) },
        };
        self.proxy.marshal_request(6, &_args) catch unreachable;
    }
    pub fn set_maximized(self: *const ShellSurface, _output: ?*Output) void {
        var _args = [_]Argument{
            .{ .object = if (_output) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(7, &_args) catch unreachable;
    }
    pub fn set_title(self: *const ShellSurface, _title: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _title },
        };
        self.proxy.marshal_request(8, &_args) catch unreachable;
    }
    pub fn set_class(self: *const ShellSurface, _class_: [*:0]const u8) void {
        var _args = [_]Argument{
            .{ .string = _class_ },
        };
        self.proxy.marshal_request(9, &_args) catch unreachable;
    }
};
pub const Surface = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_surface",
        .version = 6,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "enter",
            "leave",
            "preferred_buffer_scale",
            "preferred_buffer_transform",
        },
        .request_names = &.{
            "destroy",
            "attach",
            "damage",
            "frame",
            "set_opaque_region",
            "set_input_region",
            "commit",
            "set_buffer_transform",
            "set_buffer_scale",
            "damage_buffer",
            "offset",
        },
    };
    pub const Error = enum(c_int) {
        invalid_scale = 0,
        invalid_transform = 1,
        invalid_size = 2,
        invalid_offset = 3,
        defunct_role_object = 4,
    };
    pub const Event = union(enum) {
        enter: struct {
            output: ?u32,
        },
        leave: struct {
            output: ?u32,
        },
        preferred_buffer_scale: struct {
            factor: i32,
        },
        preferred_buffer_transform: struct {
            transform: Output.Transform,
        },
    };

    pub inline fn set_listener(
        self: *Surface,
        comptime T: type,
        comptime _listener: *const fn (*Surface, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .enter = .{
                        .output = args[0].object,
                    } },
                    1 => Event{ .leave = .{
                        .output = args[0].object,
                    } },
                    2 => Event{ .preferred_buffer_scale = .{
                        .factor = args[0].int,
                    } },
                    3 => Event{ .preferred_buffer_transform = .{
                        .transform = @bitCast(args[0].uint),
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Surface, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn destroy(self: *const Surface) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn attach(self: *const Surface, _buffer: ?*Buffer, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .object = if (_buffer) |arg| arg.proxy.id else 0 },
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn damage(self: *const Surface, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
    pub fn frame(self: *const Surface) !*Callback {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Callback, 3, &_args);
    }
    pub fn set_opaque_region(self: *const Surface, _region: ?*Region) void {
        var _args = [_]Argument{
            .{ .object = if (_region) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(4, &_args) catch unreachable;
    }
    pub fn set_input_region(self: *const Surface, _region: ?*Region) void {
        var _args = [_]Argument{
            .{ .object = if (_region) |arg| arg.proxy.id else 0 },
        };
        self.proxy.marshal_request(5, &_args) catch unreachable;
    }
    pub fn commit(self: *const Surface) void {
        self.proxy.marshal_request(6, &.{}) catch unreachable;
    }
    pub fn set_buffer_transform(self: *const Surface, _transform: Output.Transform) void {
        var _args = [_]Argument{
            .{ .int = _transform },
        };
        self.proxy.marshal_request(7, &_args) catch unreachable;
    }
    pub fn set_buffer_scale(self: *const Surface, _scale: i32) void {
        var _args = [_]Argument{
            .{ .int = _scale },
        };
        self.proxy.marshal_request(8, &_args) catch unreachable;
    }
    pub fn damage_buffer(self: *const Surface, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(9, &_args) catch unreachable;
    }
    pub fn offset(self: *const Surface, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal_request(10, &_args) catch unreachable;
    }
};
pub const Seat = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_seat",
        .version = 9,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "capabilities",
            "name",
        },
        .request_names = &.{
            "get_pointer",
            "get_keyboard",
            "get_touch",
            "release",
        },
    };
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

    pub inline fn set_listener(
        self: *Seat,
        comptime T: type,
        comptime _listener: *const fn (*Seat, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .capabilities = .{
                        .capabilities = @bitCast(args[0].uint),
                    } },
                    1 => Event{ .name = .{
                        .name = args[0].string,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Seat, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn get_pointer(self: *const Seat) !*Pointer {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Pointer, 0, &_args);
    }
    pub fn get_keyboard(self: *const Seat) !*Keyboard {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Keyboard, 1, &_args);
    }
    pub fn get_touch(self: *const Seat) !*Touch {
        var _args = [_]Argument{
            .{ .new_id = 0 },
        };
        return self.proxy.marshal_request_constructor(Touch, 2, &_args);
    }
    pub fn release(self: *const Seat) void {
        self.proxy.marshal_request(3, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const Pointer = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_pointer",
        .version = 9,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "enter",
            "leave",
            "motion",
            "button",
            "axis",
            "frame",
            "axis_source",
            "axis_stop",
            "axis_discrete",
            "axis_value120",
            "axis_relative_direction",
        },
        .request_names = &.{
            "set_cursor",
            "release",
        },
    };
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
            surface: ?u32,
            surface_x: Fixed,
            surface_y: Fixed,
        },
        leave: struct {
            serial: u32,
            surface: ?u32,
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

    pub inline fn set_listener(
        self: *Pointer,
        comptime T: type,
        comptime _listener: *const fn (*Pointer, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .enter = .{
                        .serial = args[0].uint,
                        .surface = args[1].object,
                        .surface_x = args[2].fixed,
                        .surface_y = args[3].fixed,
                    } },
                    1 => Event{ .leave = .{
                        .serial = args[0].uint,
                        .surface = args[1].object,
                    } },
                    2 => Event{ .motion = .{
                        .time = args[0].uint,
                        .surface_x = args[1].fixed,
                        .surface_y = args[2].fixed,
                    } },
                    3 => Event{ .button = .{
                        .serial = args[0].uint,
                        .time = args[1].uint,
                        .button = args[2].uint,
                        .state = @bitCast(args[3].uint),
                    } },
                    4 => Event{ .axis = .{
                        .time = args[0].uint,
                        .axis = @bitCast(args[1].uint),
                        .value = args[2].fixed,
                    } },
                    5 => Event.frame,
                    6 => Event{ .axis_source = .{
                        .axis_source = @bitCast(args[0].uint),
                    } },
                    7 => Event{ .axis_stop = .{
                        .time = args[0].uint,
                        .axis = @bitCast(args[1].uint),
                    } },
                    8 => Event{ .axis_discrete = .{
                        .axis = @bitCast(args[0].uint),
                        .discrete = args[1].int,
                    } },
                    9 => Event{ .axis_value120 = .{
                        .axis = @bitCast(args[0].uint),
                        .value120 = args[1].int,
                    } },
                    10 => Event{ .axis_relative_direction = .{
                        .axis = @bitCast(args[0].uint),
                        .direction = @bitCast(args[1].uint),
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Pointer, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn set_cursor(self: *const Pointer, _serial: u32, _surface: ?*Surface, _hotspot_x: i32, _hotspot_y: i32) void {
        var _args = [_]Argument{
            .{ .uint = _serial },
            .{ .object = if (_surface) |arg| arg.proxy.id else 0 },
            .{ .int = _hotspot_x },
            .{ .int = _hotspot_y },
        };
        self.proxy.marshal_request(0, &_args) catch unreachable;
    }
    pub fn release(self: *const Pointer) void {
        self.proxy.marshal_request(1, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const Keyboard = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_keyboard",
        .version = 9,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "keymap",
            "enter",
            "leave",
            "key",
            "modifiers",
            "repeat_info",
        },
        .request_names = &.{
            "release",
        },
    };
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
            surface: ?u32,
            keys: *anyopaque,
        },
        leave: struct {
            serial: u32,
            surface: ?u32,
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

    pub inline fn set_listener(
        self: *Keyboard,
        comptime T: type,
        comptime _listener: *const fn (*Keyboard, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .keymap = .{
                        .format = @bitCast(args[0].uint),
                        .fd = args[1].fd,
                        .size = args[2].uint,
                    } },
                    1 => Event{ .enter = .{
                        .serial = args[0].uint,
                        .surface = args[1].object,
                        .keys = undefined,
                    } },
                    2 => Event{ .leave = .{
                        .serial = args[0].uint,
                        .surface = args[1].object,
                    } },
                    3 => Event{ .key = .{
                        .serial = args[0].uint,
                        .time = args[1].uint,
                        .key = args[2].uint,
                        .state = @bitCast(args[3].uint),
                    } },
                    4 => Event{ .modifiers = .{
                        .serial = args[0].uint,
                        .mods_depressed = args[1].uint,
                        .mods_latched = args[2].uint,
                        .mods_locked = args[3].uint,
                        .group = args[4].uint,
                    } },
                    5 => Event{ .repeat_info = .{
                        .rate = args[0].int,
                        .delay = args[1].int,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Keyboard, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn release(self: *const Keyboard) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const Touch = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_touch",
        .version = 9,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "down",
            "up",
            "motion",
            "frame",
            "cancel",
            "shape",
            "orientation",
        },
        .request_names = &.{
            "release",
        },
    };
    pub const Event = union(enum) {
        down: struct {
            serial: u32,
            time: u32,
            surface: ?u32,
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

    pub inline fn set_listener(
        self: *Touch,
        comptime T: type,
        comptime _listener: *const fn (*Touch, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .down = .{
                        .serial = args[0].uint,
                        .time = args[1].uint,
                        .surface = args[2].object,
                        .id = args[3].int,
                        .x = args[4].fixed,
                        .y = args[5].fixed,
                    } },
                    1 => Event{ .up = .{
                        .serial = args[0].uint,
                        .time = args[1].uint,
                        .id = args[2].int,
                    } },
                    2 => Event{ .motion = .{
                        .time = args[0].uint,
                        .id = args[1].int,
                        .x = args[2].fixed,
                        .y = args[3].fixed,
                    } },
                    3 => Event.frame,
                    4 => Event.cancel,
                    5 => Event{ .shape = .{
                        .id = args[0].int,
                        .major = args[1].fixed,
                        .minor = args[2].fixed,
                    } },
                    6 => Event{ .orientation = .{
                        .id = args[0].int,
                        .orientation = args[1].fixed,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Touch, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn release(self: *const Touch) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const Output = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_output",
        .version = 4,
        .event_signatures = &Proxy.genEventArgs(Event),
        .event_names = &.{
            "geometry",
            "mode",
            "done",
            "scale",
            "name",
            "description",
        },
        .request_names = &.{
            "release",
        },
    };
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

    pub inline fn set_listener(
        self: *Output,
        comptime T: type,
        comptime _listener: *const fn (*Output, Event, T) void,
        _data: T,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {
                const event = switch (opcode) {
                    0 => Event{ .geometry = .{
                        .x = args[0].int,
                        .y = args[1].int,
                        .physical_width = args[2].int,
                        .physical_height = args[3].int,
                        .subpixel = args[4].int,
                        .make = args[5].string,
                        .model = args[6].string,
                        .transform = args[7].int,
                    } },
                    1 => Event{ .mode = .{
                        .flags = @bitCast(args[0].uint),
                        .width = args[1].int,
                        .height = args[2].int,
                        .refresh = args[3].int,
                    } },
                    2 => Event.done,
                    3 => Event{ .scale = .{
                        .factor = args[0].int,
                    } },
                    4 => Event{ .name = .{
                        .name = args[0].string,
                    } },
                    5 => Event{ .description = .{
                        .description = args[0].string,
                    } },
                    else => unreachable,
                };
                @call(.always_inline, _listener, .{
                    @as(*Output, @ptrCast(@alignCast(impl))),
                    event,
                    @as(T, @ptrCast(@alignCast(__data))),
                });
            }
        };

        self.proxy.listener = w.inner;
        self.proxy.listener_data = _data;
    }
    pub fn release(self: *const Output) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
};
pub const Region = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_region",
        .version = 1,
        .request_names = &.{
            "destroy",
            "add",
            "subtract",
        },
    };
    pub fn destroy(self: *const Region) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn add(self: *const Region, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn subtract(self: *const Region, _x: i32, _y: i32, _width: i32, _height: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
            .{ .int = _width },
            .{ .int = _height },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
};
pub const Subcompositor = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_subcompositor",
        .version = 1,
        .request_names = &.{
            "destroy",
            "get_subsurface",
        },
    };
    pub const Error = enum(c_int) {
        bad_surface = 0,
        bad_parent = 1,
    };
    pub fn destroy(self: *const Subcompositor) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn get_subsurface(self: *const Subcompositor, _surface: *Surface, _parent: *Surface) !*Subsurface {
        var _args = [_]Argument{
            .{ .new_id = 0 },
            .{ .object = _surface.proxy.id },
            .{ .object = _parent.proxy.id },
        };
        return self.proxy.marshal_request_constructor(Subsurface, 1, &_args);
    }
};
pub const Subsurface = struct {
    proxy: Proxy,
    pub const interface = Interface{
        .name = "wl_subsurface",
        .version = 1,
        .request_names = &.{
            "destroy",
            "set_position",
            "place_above",
            "place_below",
            "set_sync",
            "set_desync",
        },
    };
    pub const Error = enum(c_int) {
        bad_surface = 0,
    };
    pub fn destroy(self: *const Subsurface) void {
        self.proxy.marshal_request(0, &.{}) catch unreachable;
        // self.proxy.destroy();
    }
    pub fn set_position(self: *const Subsurface, _x: i32, _y: i32) void {
        var _args = [_]Argument{
            .{ .int = _x },
            .{ .int = _y },
        };
        self.proxy.marshal_request(1, &_args) catch unreachable;
    }
    pub fn place_above(self: *const Subsurface, _sibling: *Surface) void {
        var _args = [_]Argument{
            .{ .object = _sibling.proxy.id },
        };
        self.proxy.marshal_request(2, &_args) catch unreachable;
    }
    pub fn place_below(self: *const Subsurface, _sibling: *Surface) void {
        var _args = [_]Argument{
            .{ .object = _sibling.proxy.id },
        };
        self.proxy.marshal_request(3, &_args) catch unreachable;
    }
    pub fn set_sync(self: *const Subsurface) void {
        self.proxy.marshal_request(4, &.{}) catch unreachable;
    }
    pub fn set_desync(self: *const Subsurface) void {
        self.proxy.marshal_request(5, &.{}) catch unreachable;
    }
};
