const std = @import("std");
const Argument = @import("argument.zig").Argument;
const Display = @import("display.zig").Display;

pub const Proxy = struct {
    id: u32 = 0,
    display: *Display,
    event_args: []const []const Argument.ArgumentType,
    listener: ?*const fn() void = null,
    pub fn deinit(self: *Proxy) void {
        self.display.objects.items[self.id] = null;
        self.display.allocator.destroy(self);
    }
    pub fn unmarshal_event(self: *Proxy, data: []const u8, opcode: u32) void {
        const signature = self.event_args[opcode];
        var argdata = data;
        for (signature) |arg_type| {
            // std.debug.print("argdata {any}\n", .{argdata});
            const arg = Argument.unmarshal(arg_type, self.display.allocator, argdata);
            // std.debug.print("arg len: {}\n", .{arg.len()});
            argdata = argdata[arg.len()..];
            // std.debug.print("===\n", .{});
        }
    }

    pub fn marshal_request(self: *Proxy, opcode: u16, args: []const Argument) !void {
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
        std.debug.print("marshal {} {} {any}\n", .{self.id, opcode, args});
    }

    pub fn genEventArgs(comptime Event: type) [std.meta.fields(Event).len][]const Argument.ArgumentType {
        const fields = std.meta.fields(Event);
        comptime var r: [fields.len][]const Argument.ArgumentType = undefined;

        for (fields) |f, i| {
            const ev_f = std.meta.fields(f.field_type);
            comptime var argts: [ev_f.len]Argument.ArgumentType = undefined;
            for (ev_f) |sf, ii| {
                argts[ii] = switch (sf.field_type) {
                    u32 => .uint,
                    [*:0]const u8 => .string,
                    else => unreachable,
                };
            }
            r[i] = &argts;
        }
        return r;
    }
};
