const std = @import("std");
const argm = @import("argument.zig");
const Argument = argm.Argument;
const Client = @import("client.zig").Client;
const wayland = @import("lib.zig");
const wl = wayland.wl;
const log = std.log.scoped(.wl);

pub const Interface = struct {
    name: [:0]const u8,
    version: u32,
    event_signatures: []const []const Argument.ArgumentType = &.{},
    event_names: []const []const u8 = &.{},
    request_names: []const []const u8 = &.{},
};


pub const Proxy = struct {
    id: u32 = 0,
    client: *Client,
    interface: *const Interface,
    listener: ?*const fn (*anyopaque, u16, []Argument, data: ?*anyopaque) void = null,
    listener_data: ?*anyopaque = undefined,
    pub fn deinit(self: *Proxy) void {
        self.client.objects.items[self.id] = null;
        self.client.allocator.destroy(self);
    }
    pub fn unmarshal_event(self: *Proxy, data: []const u8, opcode: u16) void {
        // std.log.info("event args {any}", .{self});

        const signature = self.interface.event_signatures[opcode];
        var argdata = data;
        var args: [20]Argument = undefined;
        for (signature, 0..) |arg_type, i| {
            args[i] = Argument.unmarshal(arg_type, self.client.allocator, argdata);
            argdata = argdata[args[i].len()..];
        }
        log.debug("<- {s}@{}.{s}", .{ self.interface.name, self.id, self.interface.event_names[opcode] });
        if (self.listener) |l| {
            l(@ptrCast(self), opcode, args[0..signature.len], self.listener_data);
        }
    }

    pub fn marshal_request_constructor(self: *const Proxy, comptime T: type, opcode: u16, args: []Argument) !*T {
        const next_id = self.client.next_id();
        std.log.info("next id {}", .{next_id});
        const next = &self.client.objects.items[next_id];
        next.* = Proxy{
            .client = self.client,
            .interface = &T.interface,
            .id = next_id,
        };

        for (args) |*arg| {
            switch (arg.*) {
                .new_id => |_| arg.* = .{ .new_id = next_id },
                // .new_id => |_| arg.* = .{ .object = obj.proxy.id },
                else => {},
            }
        }
        try self.marshal_request(opcode, args);

        return @ptrCast(next);
    }

    pub fn marshal_request(self: *const Proxy, opcode: u16, args: []const Argument) !void {
        const connection = self.client.connection;
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
            if (arg == .fd) {
                const native_endian = @import("builtin").cpu.arch.endian();
                try connection.fd_out.writer().writeInt(i32, arg.fd, native_endian);
            }
        }

        log.debug("-> {s}@{}.{s}", .{ self.interface.name, self.id, self.interface.request_names[opcode] });

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

