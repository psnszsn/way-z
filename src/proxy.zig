const std = @import("std");
const Argument = @import("argument.zig").Argument;
const Display = @import("display.zig").Display;

pub const Proxy = struct {
    id: u32 = 0,
    display: *Display,
    event_args: []const []const Argument.ArgumentType,
    listener: ?*const fn (*anyopaque, u16, []Argument, data: ?*anyopaque) void = null,
    listener_data: ?*anyopaque = undefined,
    pub fn deinit(self: *Proxy) void {
        self.display.objects.items[self.id] = null;
        self.display.allocator.destroy(self);
    }
    pub fn unmarshal_event(self: *Proxy, data: []const u8, opcode: u16) void {
        // std.log.info("event args {any}", .{self});
        const signature = self.event_args[opcode];
        var argdata = data;
        var args: [20]Argument = undefined;
        for (signature, 0..) |arg_type, i| {
            // std.debug.print("argdata {any}\n", .{argdata});
            args[i] = Argument.unmarshal(arg_type, self.display.allocator, argdata);
            // std.debug.print("arg len: {}\n", .{arg.len()});
            argdata = argdata[args[i].len()..];
            // std.debug.print("===\n", .{});
        }
        if (self.listener) |l| {
            l(@ptrCast(self), opcode, args[0..signature.len], self.listener_data);
        }
    }

    pub inline fn marshal_request_constructor(self: *const Proxy, comptime T: type, opcode: u16, args: []Argument) !*T {
        var obj = try self.display.allocator.create(T);
        obj.* = .{ .proxy = .{
            .display = self.display,
            .event_args = if (@hasDecl(T, "event_signatures")) &T.event_signatures else &.{},
        } };
        try self.display.objects.append(&obj.proxy);
        obj.proxy.id = @intCast(self.display.objects.items.len - 1);

        for (args) |*arg| {
            switch (arg.*) {
                .new_id => |_| arg.* = .{ .new_id = obj.proxy.id },
                // .new_id => |_| arg.* = .{ .object = obj.proxy.id },
                else => {},
            }
        }
        try self.marshal_request(opcode, args);

        const ret = try self.display.connection.send();
        std.debug.print("sent {}\n", .{ret});

        return obj;
    }

    pub fn marshal_request(self: *const Proxy, opcode: u16, args: []const Argument) !void {
        const connection = self.display.connection;
        try connection.out.pushSlice(std.mem.asBytes(&self.id));
        try connection.out.pushSlice(std.mem.asBytes(&opcode));
        var size: u16 = 0;
        for (args) |arg| {
            size += arg.len();
        }
        try connection.out.pushSlice(&std.mem.toBytes(8 + size));

        const writer = connection.out.writer();
        for (args) |arg| {
            try arg.marshal(writer);
        }

        // try connection.out.pushSlice(std.mem.asBytes(&@as(u32, 2)));
        std.debug.print("{}\n", .{std.fmt.fmtSliceEscapeUpper(connection.out.bfr[0..connection.out.count])});
        // var get_registry = "\x01\x00\x00\x00\x01\x00\x0c\x00\x02\x00\x00\x00";
        std.debug.print("marshal {} {} {any}\n", .{ self.id, opcode, args });
    }

    pub fn setListener(
        self: *Proxy,
        comptime Event: type,
        comptime cb: *const fn (self: *anyopaque, event: Event, data: ?*anyopaque) void,
        data: ?*anyopaque,
    ) void {
        const w = struct {
            fn inner(impl: *anyopaque, opcode: u16, args: []Argument, _data: ?*anyopaque) void {
                for (args) |arg| {
                    _ = arg;
                    const fields = @typeInfo(Event).Union.fields;
                    return switch (opcode) {
                        inline 0...fields.len - 1 => |_op| {
                            const union_variant = fields[_op];
                            var event: union_variant.type = undefined;
                            if (@typeInfo(union_variant.type) != .Struct) continue;
                            const variant_fields = @typeInfo(union_variant.type).Struct.fields;
                            inline for (variant_fields, 0..) |f, i| {
                                // switch (args[i]) {
                                //     .string => |str| @field(event, f.name) = str,
                                //     else => {},
                                // }
                                switch (f.type) {
                                    [*:0]const u8 => @field(event, f.name) = args[i].string,
                                    else => switch (@typeInfo(f.type)) {
                                        .Int, .Struct => @field(event, f.name) = @bitCast(args[i].uint),
                                        // .Pointer => @field(event, f.name) = args[i].object,
                                        .Optional => @field(event, f.name) = @as(f.type, @ptrFromInt(args[i].object)),

                                        // .Enum => @field(event, f.name) = @enumFromInt(args[i].uint),

                                        else => {
                                            std.debug.print("{}\n", .{f.type});
                                            unreachable;
                                        },
                                    },
                                }
                            }
                            // TODO: use .always_inline
                            @call(.auto, cb, .{
                                impl,
                                @unionInit(Event, union_variant.name, event),
                                _data,
                            });
                            return;
                        },
                        else => unreachable,
                    };
                }
            }
        };
        self.listener = w.inner;
        self.listener_data = data;
    }

    pub fn genEventArgs(comptime Event: type) [std.meta.fields(Event).len][]const Argument.ArgumentType {
        const fields = std.meta.fields(Event);
        comptime var r: [fields.len][]const Argument.ArgumentType = undefined;

        inline for (fields, 0..) |f, i| {
            if (f.type == void) continue;
            const ev_f = std.meta.fields(f.type);
            comptime var argts: [ev_f.len]Argument.ArgumentType = undefined;
            for (ev_f, 0..) |sf, ii| {
                argts[ii] = switch (sf.type) {
                    u32 => .uint,
                    i32 => .int,
                    [*:0]const u8 => .string,
                    ?*anyopaque => .object,
                    else => .uint,
                };
            }
            r[i] = &argts;
        }
        return r;
    }
};
