// Copyright © 2017 Drew DeVault
//
// Permission to use, copy, modify, distribute, and sell this
// software and its documentation for any purpose is hereby granted
// without fee, provided that the above copyright notice appear in
// all copies and that both that copyright notice and this permission
// notice appear in supporting documentation, and that the name of
// the copyright holders not be used in advertising or publicity
// pertaining to distribution of the software without specific,
// written prior permission.  The copyright holders make no
// representations about the suitability of this software for any
// purpose.  It is provided "as is" without express or implied
// warranty.
//
// THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
// SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS, IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
// SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
// AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
// ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF
// THIS SOFTWARE.

/// Clients can use this interface to assign the surface_layer role to
/// wl_surfaces. Such surfaces are assigned to a "layer" of the output and
/// rendered with a defined z-depth respective to each other. They may also be
/// anchored to the edges and corners of a screen and specify input handling
/// semantics. This interface should be suitable for the implementation of
/// many desktop shell components, and a broad number of other applications
/// that interact with the desktop.
pub const LayerShellV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwlr_layer_shell_v1",
        .version = 4,
        .request_names = &.{
            "get_layer_surface",
            "destroy",
        },
    };
    pub const Error = enum(c_int) {
        role = 0,
        invalid_layer = 1,
        already_constructed = 2,
    };
    pub const Layer = enum(c_int) {
        background = 0,
        bottom = 1,
        top = 2,
        overlay = 3,
    };
    pub const Request = union(enum) {
        /// Create a layer surface for an existing surface. This assigns the role of
        /// layer_surface, or raises a protocol error if another role is already
        /// assigned.
        ///
        /// Creating a layer surface from a wl_surface which has a buffer attached
        /// or committed is a client error, and any attempts by a client to attach
        /// or manipulate a buffer prior to the first layer_surface.configure call
        /// must also be treated as errors.
        ///
        /// After creating a layer_surface object and setting it up, the client
        /// must perform an initial commit without any buffer attached.
        /// The compositor will reply with a layer_surface.configure event.
        /// The client must acknowledge it and is then allowed to attach a buffer
        /// to map the surface.
        ///
        /// You may pass NULL for output to allow the compositor to decide which
        /// output to use. Generally this will be the one that the user most
        /// recently interacted with.
        ///
        /// Clients can specify a namespace that defines the purpose of the layer
        /// surface.
        get_layer_surface: struct {
            id: LayerSurfaceV1 = @enumFromInt(0),
            surface: ?wl.Surface,
            output: ?wl.Output,
            layer: Layer, // layer to add this surface to
            namespace: [:0]const u8, // namespace for the layer surface
        },
        /// This request indicates that the client will not use the layer_shell
        /// object any more. Objects that have been created through this instance
        /// are not affected.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .get_layer_surface => LayerSurfaceV1,
                .destroy => void,
            };
        }
    };
};

/// An interface that may be implemented by a wl_surface, for surfaces that
/// are designed to be rendered as a layer of a stacked desktop-like
/// environment.
///
/// Layer surface state (layer, size, anchor, exclusive zone,
/// margin, interactivity) is double-buffered, and will be applied at the
/// time wl_surface.commit of the corresponding wl_surface is called.
///
/// Attaching a null buffer to a layer surface unmaps it.
///
/// Unmapping a layer_surface means that the surface cannot be shown by the
/// compositor until it is explicitly mapped again. The layer_surface
/// returns to the state it had right after layer_shell.get_layer_surface.
/// The client can re-map the surface by performing a commit without any
/// buffer attached, waiting for a configure event and handling it as usual.
pub const LayerSurfaceV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwlr_layer_surface_v1",
        .version = 4,
        .event_signatures = &.{
            &.{ .uint, .uint, .uint },
            &.{},
        },
        .event_names = &.{
            "configure",
            "closed",
        },
        .request_names = &.{
            "set_size",
            "set_anchor",
            "set_exclusive_zone",
            "set_margin",
            "set_keyboard_interactivity",
            "get_popup",
            "ack_configure",
            "destroy",
            "set_layer",
        },
    };
    pub const KeyboardInteractivity = enum(c_int) {
        none = 0,
        exclusive = 1,
        on_demand = 2,
    };
    pub const Error = enum(c_int) {
        invalid_surface_state = 0,
        invalid_size = 1,
        invalid_anchor = 2,
        invalid_keyboard_interactivity = 3,
    };
    pub const Anchor = packed struct(u32) {
        top: bool = false,
        bottom: bool = false,
        left: bool = false,
        right: bool = false,
        _padding: u28 = 0,
    };
    pub const Event = union(enum) {
        /// The configure event asks the client to resize its surface.
        ///
        /// Clients should arrange their surface for the new states, and then send
        /// an ack_configure request with the serial sent in this configure event at
        /// some point before committing the new surface.
        ///
        /// The client is free to dismiss all but the last configure event it
        /// received.
        ///
        /// The width and height arguments specify the size of the window in
        /// surface-local coordinates.
        ///
        /// The size is a hint, in the sense that the client is free to ignore it if
        /// it doesn't resize, pick a smaller size (to satisfy aspect ratio or
        /// resize in steps of NxM pixels). If the client picks a smaller size and
        /// is anchored to two opposite anchors (e.g. 'top' and 'bottom'), the
        /// surface will be centered on this axis.
        ///
        /// If the width or height arguments are zero, it means the client should
        /// decide its own window dimension.
        configure: struct {
            serial: u32,
            width: u32,
            height: u32,
        },
        /// The closed event is sent by the compositor when the surface will no
        /// longer be shown. The output may have been destroyed or the user may
        /// have asked for it to be removed. Further changes to the surface will be
        /// ignored. The client should destroy the resource after receiving this
        /// event, and create a new surface if they so choose.
        closed: void,

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .configure = .{
                        .serial = args[0].uint,
                        .width = args[1].uint,
                        .height = args[2].uint,
                    },
                },
                1 => Event.closed,
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Sets the size of the surface in surface-local coordinates. The
        /// compositor will display the surface centered with respect to its
        /// anchors.
        ///
        /// If you pass 0 for either value, the compositor will assign it and
        /// inform you of the assignment in the configure event. You must set your
        /// anchor to opposite edges in the dimensions you omit; not doing so is a
        /// protocol error. Both values are 0 by default.
        ///
        /// Size is double-buffered, see wl_surface.commit.
        set_size: struct {
            width: u32,
            height: u32,
        },
        /// Requests that the compositor anchor the surface to the specified edges
        /// and corners. If two orthogonal edges are specified (e.g. 'top' and
        /// 'left'), then the anchor point will be the intersection of the edges
        /// (e.g. the top left corner of the output); otherwise the anchor point
        /// will be centered on that edge, or in the center if none is specified.
        ///
        /// Anchor is double-buffered, see wl_surface.commit.
        set_anchor: struct {
            anchor: Anchor,
        },
        /// Requests that the compositor avoids occluding an area with other
        /// surfaces. The compositor's use of this information is
        /// implementation-dependent - do not assume that this region will not
        /// actually be occluded.
        ///
        /// A positive value is only meaningful if the surface is anchored to one
        /// edge or an edge and both perpendicular edges. If the surface is not
        /// anchored, anchored to only two perpendicular edges (a corner), anchored
        /// to only two parallel edges or anchored to all edges, a positive value
        /// will be treated the same as zero.
        ///
        /// A positive zone is the distance from the edge in surface-local
        /// coordinates to consider exclusive.
        ///
        /// Surfaces that do not wish to have an exclusive zone may instead specify
        /// how they should interact with surfaces that do. If set to zero, the
        /// surface indicates that it would like to be moved to avoid occluding
        /// surfaces with a positive exclusive zone. If set to -1, the surface
        /// indicates that it would not like to be moved to accommodate for other
        /// surfaces, and the compositor should extend it all the way to the edges
        /// it is anchored to.
        ///
        /// For example, a panel might set its exclusive zone to 10, so that
        /// maximized shell surfaces are not shown on top of it. A notification
        /// might set its exclusive zone to 0, so that it is moved to avoid
        /// occluding the panel, but shell surfaces are shown underneath it. A
        /// wallpaper or lock screen might set their exclusive zone to -1, so that
        /// they stretch below or over the panel.
        ///
        /// The default value is 0.
        ///
        /// Exclusive zone is double-buffered, see wl_surface.commit.
        set_exclusive_zone: struct {
            zone: i32,
        },
        /// Requests that the surface be placed some distance away from the anchor
        /// point on the output, in surface-local coordinates. Setting this value
        /// for edges you are not anchored to has no effect.
        ///
        /// The exclusive zone includes the margin.
        ///
        /// Margin is double-buffered, see wl_surface.commit.
        set_margin: struct {
            top: i32,
            right: i32,
            bottom: i32,
            left: i32,
        },
        /// Set how keyboard events are delivered to this surface. By default,
        /// layer shell surfaces do not receive keyboard events; this request can
        /// be used to change this.
        ///
        /// This setting is inherited by child surfaces set by the get_popup
        /// request.
        ///
        /// Layer surfaces receive pointer, touch, and tablet events normally. If
        /// you do not want to receive them, set the input region on your surface
        /// to an empty region.
        ///
        /// Keyboard interactivity is double-buffered, see wl_surface.commit.
        set_keyboard_interactivity: struct {
            keyboard_interactivity: KeyboardInteractivity,
        },
        /// This assigns an xdg_popup's parent to this layer_surface.  This popup
        /// should have been created via xdg_surface::get_popup with the parent set
        /// to NULL, and this request must be invoked before committing the popup's
        /// initial state.
        ///
        /// See the documentation of xdg_popup for more details about what an
        /// xdg_popup is and how it is used.
        get_popup: struct {
            popup: ?xdg.Popup,
        },
        /// When a configure event is received, if a client commits the
        /// surface in response to the configure event, then the client
        /// must make an ack_configure request sometime before the commit
        /// request, passing along the serial of the configure event.
        ///
        /// If the client receives multiple configure events before it
        /// can respond to one, it only has to ack the last configure event.
        ///
        /// A client is not required to commit immediately after sending
        /// an ack_configure request - it may even ack_configure several times
        /// before its next surface commit.
        ///
        /// A client may send multiple ack_configure requests before committing, but
        /// only the last request sent before a commit indicates which configure
        /// event the client really is responding to.
        ack_configure: struct {
            serial: u32, // the serial from the configure event
        },
        /// This request destroys the layer surface.
        destroy: void,
        /// Change the layer that the surface is rendered on.
        ///
        /// Layer is double-buffered, see wl_surface.commit.
        set_layer: struct {
            layer: LayerShellV1.Layer, // layer to move this surface to
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .set_size => void,
                .set_anchor => void,
                .set_exclusive_zone => void,
                .set_margin => void,
                .set_keyboard_interactivity => void,
                .get_popup => void,
                .ack_configure => void,
                .destroy => void,
                .set_layer => void,
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
const wl = @import("wl.zig");
