const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const IO = @import("io_async.zig").IO;
const IO_Uring = linux.IO_Uring;
const Argument = @import("argument.zig").Argument;
const Proxy = @import("proxy.zig").Proxy;
const Display = @import("display.zig").Display;
const Callback = @import("display.zig").Callback;
const gen = @import("generated/wl.zig");

const libcoro = @import("libcoro");

pub const xasync = libcoro.xasync;
pub const xawait = libcoro.xawait;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// defer std.debug.assert(!gpa.deinit());

const allocator = gpa.allocator();

pub fn main() !void {
    const stack = try libcoro.stackAlloc(
        allocator,
        1024 * 32,
    );

    var io = IO.init(32, 0) catch unreachable;
    defer io.deinit();
    // var f1 = async signals(&io);
    var frame = try xasync(way, .{&io}, stack);
    _ = &frame;
    io.run() catch unreachable;
    // nosuspend await frame catch unreachable;

}

const A = struct {
    a: usize = 10,
    pub fn asd(a: B) void {
        std.debug.print("a {}\n", .{a.a});
    }
};

const B = struct {
    a: usize = 11,
    usingnamespace A;
};

// pub const Registry = struct {
//     pub const interface_name = "wl_registry";
//     pub const version = 1;
//     proxy: Proxy,
//
//     pub const Event = union(enum) {
//         global: struct {
//             name: u32,
//             interface: [*:0]const u8,
//             version: u32,
//         },
//         global_remove: struct {
//             name: u32,
//         },
//     };
//     pub const event_signatures = Proxy.genEventArgs(Event);
//
//     pub fn deinit(self: *Registry) void {
//         self.proxy.deinit();
//     }
// };

fn registryListener(self: *gen.Registry, event: gen.Registry.Event, data: *anyopaque) void {
    _ = self;
    _ = data;
    std.log.info("event: {s}", .{event.global.interface});
}
fn cbListener(event: Callback.Event, data: *anyopaque) void {
    _ = data;
    std.log.info("event: {}", .{event});
}
fn displayListener(self: *Display, event: Display.Event, data: *anyopaque) void {
    _ = self;
    _ = data;
    switch (event) {
        .@"error" => |ev| {
            std.log.info("display error {}", .{ev});
        },
        .delete_id => |ev| {
            std.log.info("delete id {}", .{ev.id});
            // if (ev.id == 3) {
            //     var cb = ddd.sync() catch unreachable;
            //     cb.proxy.set_listener(Callback.Event, cbListener);
            // }
        },
    }
}

pub fn way(io: *IO) !void {
    var display = try Display.connect(allocator, io);
    defer display.deinit();
    var registry = try display.get_registry();
    _ = &registry;
    // defer registry.deinit();

    registry.set_listener(
        *anyopaque,
        registryListener,
        @ptrFromInt(7),
    );
    display.set_listener(
        *anyopaque,
        displayListener,
        @ptrFromInt(7),
    );

    while (true) {
        try display.recvEvents();
        std.debug.print("count {}\n", .{display.connection.in.count});
        // if (display.connection.in.count == 0) break;
    }
    // try display.recvEvents();
}

pub fn signals(io: *IO) !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    const os = std.os;
    var mask = os.linux.empty_sigset;
    os.linux.sigaddset(&mask, os.SIG.INT);
    os.linux.sigaddset(&mask, os.SIG.TSTP);
    const r = os.linux.sigprocmask(os.SIG.BLOCK, &mask, null);
    const sigfd = try os.signalfd(-1, &mask, 0);
    std.debug.print("R{}\n", .{r});

    while (true) {
        const events = try io.poll_add(sigfd, os.POLL.IN);
        std.debug.assert(events == 1);

        var si: os.linux.signalfd_siginfo = undefined;
        // maybe do it synchronously instead?
        const bytes_read = try io.read(sigfd, std.mem.asBytes(&si), 0);
        std.debug.assert(bytes_read == @sizeOf(@TypeOf(si)));
        std.debug.print("si: {}\n", .{si});

        std.debug.print("PID: {}\n", .{os.linux.getpid()});
        os.exit(1);
    }
}

fn asdf(ptr: *u32) void {
    std.debug.print("value: {}", .{ptr.*});
}
test {
    _ = @import("argument.zig");
    _ = @import("ring_buffer.zig");
    var fn_ptr: *const fn (*anyopaque) void = @ptrCast(&asdf);
    _ = &fn_ptr;
    var a: u32 = 77;
    @call(.auto, fn_ptr, .{@as(*anyopaque, @ptrCast(&a))});

    
}
