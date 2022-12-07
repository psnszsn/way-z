const std = @import("std");
const Argument = @import("argument.zig").Argument;
const Display = @import("display.zig").Display;

pub const Proxy = struct {
    id: u32 = 0,
    display: *Display,
    event_args: []const []const Argument.ArgumentType,
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
