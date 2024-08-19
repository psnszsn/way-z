pub const Client = @import("client.zig").Client;
pub const Argument = @import("argument.zig").Argument;
pub const Proxy = @import("proxy.zig").Proxy;
pub const shm = @import("shm.zig");

pub const wl = @import("generated/wl.zig");
pub const xdg = @import("generated/xdg.zig");
pub const zwlr = @import("generated/zwlr.zig");
pub const wp = @import("generated/wp.zig");
pub const zwp = @import("generated/zwp.zig");

test {
    _ = @import("shm.zig");
}
