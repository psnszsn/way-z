const std = @import("std");
const argm = @import("argument.zig");
const Argument = argm.Argument;
const Client = @import("client.zig").Client;
const log = std.log.scoped(.wl);

pub const Interface = struct {
    name: [:0]const u8,
    version: u32,
    event_signatures: []const []const Argument.ArgumentType = &.{},
    event_names: []const []const u8 = &.{},
    request_names: []const []const u8 = &.{},
};

pub const ObjectAttrs = struct {
    interface: *const Interface,
    listener: ?*const fn (*Client, u32, u16, []Argument, data: ?*anyopaque) void = null,
    listener_data: ?*anyopaque = undefined,
    is_free: bool = false,
};

pub const Proxy = struct {
    id: u32 = 0,
    client: *Client,

    pub fn init(
        self: Proxy,
        atrrs: ObjectAttrs,
    ) void {
        self.client.objects.set(self.id, atrrs);
    }

    pub fn get(
        self: Proxy,
        comptime item: std.meta.FieldEnum(ObjectAttrs),
    ) std.meta.FieldType(ObjectAttrs, item) {
        return self.client.objects.items(item)[self.id];
    }

    pub fn set(
        self: Proxy,
        comptime item: std.meta.FieldEnum(ObjectAttrs),
        value: std.meta.FieldType(ObjectAttrs, item),
    ) void {
        self.client.objects.items(item)[self.id] = value;
    }

    pub fn destroy(self: Proxy) void {
        self.set(.is_free, true);
    }

    pub fn unmarshal_event(self: Proxy, data: []const u8, opcode: u16) void {
        // std.log.info("unmarshal {any}", .{self.id});

        const interface = self.get(.interface);
        const listener = self.get(.listener);
        const listener_data = self.get(.listener_data);

        const signature = interface.event_signatures[opcode];
        var argdata = data;
        var args: [20]Argument = undefined;
        for (signature, 0..) |arg_type, i| {
            args[i] = Argument.unmarshal(arg_type, self.client.allocator, argdata);
            argdata = argdata[args[i].len()..];
        }
        // log.debug("<- {s}@{}.{s}", .{ interface.name, self.id, interface.event_names[opcode] });
        if (listener) |l| {
            l(self.client, self.id, opcode, args[0..signature.len], listener_data);
        }
    }

    pub fn marshal_request_constructor(self: Proxy, comptime T: type, opcode: u16, args: []Argument) !T {
        const next_proxy = self.client.next_object();
        // std.log.info("next id {}", .{next_proxy.id});
        self.client.objects.set(next_proxy.id, .{
            .interface = &T.interface,
        });

        for (args) |*arg| {
            switch (arg.*) {
                .new_id => |_| arg.* = .{ .new_id = next_proxy.id },
                // .new_id => |_| arg.* = .{ .object = obj.proxy.id },
                else => {},
            }
        }
        try self.marshal_request(opcode, args);

        return @enumFromInt(next_proxy.id);
    }

    pub fn marshal_request(self: Proxy, opcode: u16, args: []const Argument) !void {
        const connection = self.client.connection;
        try connection.out.pushSlice(&std.mem.toBytes(self.id));
        try connection.out.pushSlice(std.mem.asBytes(&opcode));
        var size: u16 = 0;
        for (args) |arg| {
            size += arg.len();
        }
        try connection.out.pushSlice(&std.mem.toBytes(8 + size));

        const writer = connection.out.writer();
        for (args) |arg| {
            try arg.marshal(writer);
            if (arg == .fd) {
                const native_endian = @import("builtin").cpu.arch.endian();
                try connection.fd_out.writer().writeInt(i32, arg.fd, native_endian);
            }
        }

        // log.debug("-> {s}@{}.{s}", .{ self.interface.name, self.id, self.interface.request_names[opcode] });

        // const ret = try self.display.connection.send();
        // _ = ret;
        // std.debug.print("sent {}\n", .{ret});

        // std.debug.print("{}\n", .{std.fmt.fmtSliceEscapeUpper(connection.out.bfr[0..connection.out.count])});
        // var get_registry = "\x01\x00\x00\x00\x01\x00\x0c\x00\x02\x00\x00\x00";
        // std.debug.print("marshal {} {} {any}\n", .{ self.id, opcode, args });
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
                    [:0]const u8 => .string,
                    ?*anyopaque => .object,
                    argm.Fixed => .fixed,
                    else => .uint,
                };
            }
            r[i] = &argts;
        }
        return r;
    }
};

pub fn RequestArgs(comptime Request: type, tag: std.meta.Tag(Request)) type {
    const Payload = std.meta.TagPayload(Request, tag);
    comptime var payload_len = if (Payload == void) 0 else std.meta.fields(Payload).len;
    const RT = Request.ReturnType(tag);
    if (RT != void) payload_len += 1;
    return [payload_len]Argument;
}

pub fn request_to_args(
    comptime RequestType: type,
    comptime tag: std.meta.Tag(RequestType),
    payload: std.meta.TagPayload(RequestType, tag),
    // request: std.meta.Tag(Request),
) RequestArgs(RequestType, tag) {
    const RA = RequestArgs(RequestType, tag);
    const RT = RequestType.ReturnType(tag);

    if (@TypeOf(payload) != void) {}
    var args: RA = undefined;
    const len = @typeInfo(RA).Array.len;
    _ = len; // autofix
    const payload_fields = if (@TypeOf(payload) == void) .{} else std.meta.fields(@TypeOf(payload));

    comptime var i = 0;
    if (RT != void) {
        args[0] = .{ .new_id = 0 };
        i += 1;
    }

    inline for (payload_fields) |f| {
        const field_value = @field(payload, f.name);
        // std.log.info("f:{}", .{field_value});
        args[i] = switch (@TypeOf(field_value)) {
            u32 => .{ .uint = field_value },
            i32 => b: {
                if (std.mem.eql(u8, f.name, "fd")) {
                    break :b .{ .fd = field_value };
                }
                break :b .{ .int = field_value };
            },
            [:0]const u8 => .{ .string = field_value },
            ?*anyopaque => .{ .object = if (field_value) |v| @intFromEnum(v) else 0 },
            *anyopaque => .{ .object = @intFromEnum(field_value) },
            argm.Fixed => .{ .fixed = field_value },
            else => |v| switch (@typeInfo(v)) {
                .Optional => .{ .object = if (field_value) |b| @intFromEnum(b) else 0 },
                .Struct => |s| if (s.layout == .@"packed") .{
                    .object = @bitCast(field_value),
                } else .{
                    .uint = @bitCast(field_value),
                },
                // TODO: packed struct -> uint
                .Enum => .{ .uint = @intCast(@intFromEnum(field_value)) },
                else => unreachable,
            },
        };
        i += 1;
    }
    // std.log.warn("Z: {any}", .{args});
    return args;
}
