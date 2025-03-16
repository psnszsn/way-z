// Copyright © 2018 Simon Ser
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice (including the next
// paragraph) shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

/// This interface allows a compositor to announce support for server-side
/// decorations.
///
/// A window decoration is a set of window controls as deemed appropriate by
/// the party managing them, such as user interface components used to move,
/// resize and change a window's state.
///
/// A client can use this protocol to request being decorated by a supporting
/// compositor.
///
/// If compositor and client do not negotiate the use of a server-side
/// decoration using this protocol, clients continue to self-decorate as they
/// see fit.
///
/// Warning! The protocol described in this file is experimental and
/// backward incompatible changes may be made. Backward compatible changes
/// may be added together with the corresponding interface version bump.
/// Backward incompatible changes are done by bumping the version number in
/// the protocol and interface names and resetting the interface version.
/// Once the protocol is to be declared stable, the 'z' prefix and the
/// version number in the protocol and interface names are removed and the
/// interface version number is reset.
pub const DecorationManagerV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zxdg_decoration_manager_v1",
        .version = 1,
        .request_names = &.{
            "destroy",
            "get_toplevel_decoration",
        },
    };
    pub const Request = union(enum) {
        /// Destroy the decoration manager. This doesn't destroy objects created
        /// with the manager.
        destroy: void,
        /// Create a new decoration object associated with the given toplevel.
        ///
        /// Creating an xdg_toplevel_decoration from an xdg_toplevel which has a
        /// buffer attached or committed is a client error, and any attempts by a
        /// client to attach or manipulate a buffer prior to the first
        /// xdg_toplevel_decoration.configure event must also be treated as
        /// errors.
        get_toplevel_decoration: struct {
            id: ToplevelDecorationV1 = @enumFromInt(0),
            toplevel: ?xdg.Toplevel,
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .get_toplevel_decoration => ToplevelDecorationV1,
            };
        }
    };
};

/// The decoration object allows the compositor to toggle server-side window
/// decorations for a toplevel surface. The client can request to switch to
/// another mode.
///
/// The xdg_toplevel_decoration object must be destroyed before its
/// xdg_toplevel.
pub const ToplevelDecorationV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zxdg_toplevel_decoration_v1",
        .version = 1,
        .event_signatures = &.{
            &.{.uint},
        },
        .event_names = &.{
            "configure",
        },
        .request_names = &.{
            "destroy",
            "set_mode",
            "unset_mode",
        },
    };
    pub const Error = enum(c_int) {
        unconfigured_buffer = 0,
        already_constructed = 1,
        orphaned = 2,
        invalid_mode = 3,
    };
    pub const Mode = enum(c_int) {
        client_side = 1,
        server_side = 2,
    };
    pub const Event = union(enum) {
        /// The configure event configures the effective decoration mode. The
        /// configured state should not be applied immediately. Clients must send an
        /// ack_configure in response to this event. See xdg_surface.configure and
        /// xdg_surface.ack_configure for details.
        ///
        /// A configure event can be sent at any time. The specified mode must be
        /// obeyed by the client.
        configure: struct {
            mode: Mode, // the decoration mode
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .configure = .{
                        .mode = @enumFromInt(args[0].uint),
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Switch back to a mode without any server-side decorations at the next
        /// commit.
        destroy: void,
        /// Set the toplevel surface decoration mode. This informs the compositor
        /// that the client prefers the provided decoration mode.
        ///
        /// After requesting a decoration mode, the compositor will respond by
        /// emitting an xdg_surface.configure event. The client should then update
        /// its content, drawing it without decorations if the received mode is
        /// server-side decorations. The client must also acknowledge the configure
        /// when committing the new content (see xdg_surface.ack_configure).
        ///
        /// The compositor can decide not to use the client's mode and enforce a
        /// different mode instead.
        ///
        /// Clients whose decoration mode depend on the xdg_toplevel state may send
        /// a set_mode request in response to an xdg_surface.configure event and wait
        /// for the next xdg_surface.configure event to prevent unwanted state.
        /// Such clients are responsible for preventing configure loops and must
        /// make sure not to send multiple successive set_mode requests with the
        /// same decoration mode.
        ///
        /// If an invalid mode is supplied by the client, the invalid_mode protocol
        /// error is raised by the compositor.
        set_mode: struct {
            mode: Mode, // the decoration mode
        },
        /// Unset the toplevel surface decoration mode. This informs the compositor
        /// that the client doesn't prefer a particular decoration mode.
        ///
        /// This request has the same semantics as set_mode.
        unset_mode: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .set_mode => void,
                .unset_mode => void,
            };
        }
    };
};
const std = @import("std");
const os = std.os;
const Proxy = @import("../proxy.zig").Proxy;
const Interface = @import("../proxy.zig").Interface;
const Argument = @import("../argument.zig").Argument;
const Fixed = @import("../argument.zig").Fixed;
const Client = @import("../client.zig").Client;

const xdg = @import("xdg.zig");
