// Copyright 2018 The Chromium Authors
// Copyright 2023 Simon Ser
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice (including the next
// paragraph) shall be included in all copies or substantial portions of the
// Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

/// This global offers an alternative, optional way to set cursor images. This
/// new way uses enumerated cursors instead of a wl_surface like
/// wl_pointer.set_cursor does.
///
/// Warning! The protocol described in this file is currently in the testing
/// phase. Backward compatible changes may be added together with the
/// corresponding interface version bump. Backward incompatible changes can
/// only be done by creating a new major version of the extension.
pub const CursorShapeManagerV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_cursor_shape_manager_v1",
        .version = 2,
        .request_names = &.{
            "destroy",
            "get_pointer",
            "get_tablet_tool_v2",
        },
    };
    pub const Request = union(enum) {
        /// Destroy the cursor shape manager.
        destroy: void,
        /// Obtain a wp_cursor_shape_device_v1 for a wl_pointer object.
        ///
        /// When the pointer capability is removed from the wl_seat, the
        /// wp_cursor_shape_device_v1 object becomes inert.
        get_pointer: struct {
            cursor_shape_device: CursorShapeDeviceV1 = @enumFromInt(0),
            pointer: ?wl.Pointer,
        },
        /// Obtain a wp_cursor_shape_device_v1 for a zwp_tablet_tool_v2 object.
        ///
        /// When the zwp_tablet_tool_v2 is removed, the wp_cursor_shape_device_v1
        /// object becomes inert.
        get_tablet_tool_v2: struct {
            cursor_shape_device: CursorShapeDeviceV1 = @enumFromInt(0),
            tablet_tool: ?zwp.TabletToolV2,
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .get_pointer => CursorShapeDeviceV1,
                .get_tablet_tool_v2 => CursorShapeDeviceV1,
            };
        }
    };
};

/// This interface allows clients to set the cursor shape.
pub const CursorShapeDeviceV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_cursor_shape_device_v1",
        .version = 2,
        .request_names = &.{
            "destroy",
            "set_shape",
        },
    };
    pub const Shape = enum(c_int) {
        default = 1,
        context_menu = 2,
        help = 3,
        pointer = 4,
        progress = 5,
        wait = 6,
        cell = 7,
        crosshair = 8,
        text = 9,
        vertical_text = 10,
        alias = 11,
        copy = 12,
        move = 13,
        no_drop = 14,
        not_allowed = 15,
        grab = 16,
        grabbing = 17,
        e_resize = 18,
        n_resize = 19,
        ne_resize = 20,
        nw_resize = 21,
        s_resize = 22,
        se_resize = 23,
        sw_resize = 24,
        w_resize = 25,
        ew_resize = 26,
        ns_resize = 27,
        nesw_resize = 28,
        nwse_resize = 29,
        col_resize = 30,
        row_resize = 31,
        all_scroll = 32,
        zoom_in = 33,
        zoom_out = 34,
        dnd_ask = 35,
        all_resize = 36,
    };
    pub const Error = enum(c_int) {
        invalid_shape = 1,
    };
    pub const Request = union(enum) {
        /// Destroy the cursor shape device.
        ///
        /// The device cursor shape remains unchanged.
        destroy: void,
        /// Sets the device cursor to the specified shape. The compositor will
        /// change the cursor image based on the specified shape.
        ///
        /// The cursor actually changes only if the input device focus is one of
        /// the requesting client's surfaces. If any, the previous cursor image
        /// (surface or shape) is replaced.
        ///
        /// The "shape" argument must be a valid enum entry, otherwise the
        /// invalid_shape protocol error is raised.
        ///
        /// This is similar to the wl_pointer.set_cursor and
        /// zwp_tablet_tool_v2.set_cursor requests, but this request accepts a
        /// shape instead of contents in the form of a surface. Clients can mix
        /// set_cursor and set_shape requests.
        ///
        /// The serial parameter must match the latest wl_pointer.enter or
        /// zwp_tablet_tool_v2.proximity_in serial number sent to the client.
        /// Otherwise the request will be ignored.
        set_shape: struct {
            serial: u32, // serial number of the enter event
            shape: Shape,
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .set_shape => void,
            };
        }
    };
};

// Copyright © 2013-2016 Collabora, Ltd.
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

/// The global interface exposing surface cropping and scaling
/// capabilities is used to instantiate an interface extension for a
/// wl_surface object. This extended interface will then allow
/// cropping and scaling the surface contents, effectively
/// disconnecting the direct relationship between the buffer and the
/// surface size.
pub const Viewporter = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_viewporter",
        .version = 1,
        .request_names = &.{
            "destroy",
            "get_viewport",
        },
    };
    pub const Error = enum(c_int) {
        viewport_exists = 0,
    };
    pub const Request = union(enum) {
        /// Informs the server that the client will not be using this
        /// protocol object anymore. This does not affect any other objects,
        /// wp_viewport objects included.
        destroy: void,
        /// Instantiate an interface extension for the given wl_surface to
        /// crop and scale its content. If the given wl_surface already has
        /// a wp_viewport object associated, the viewport_exists
        /// protocol error is raised.
        get_viewport: struct {
            id: Viewport = @enumFromInt(0), // the new viewport interface id
            surface: ?wl.Surface, // the surface
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .get_viewport => Viewport,
            };
        }
    };
};

/// An additional interface to a wl_surface object, which allows the
/// client to specify the cropping and scaling of the surface
/// contents.
///
/// This interface works with two concepts: the source rectangle (src_x,
/// src_y, src_width, src_height), and the destination size (dst_width,
/// dst_height). The contents of the source rectangle are scaled to the
/// destination size, and content outside the source rectangle is ignored.
/// This state is double-buffered, see wl_surface.commit.
///
/// The two parts of crop and scale state are independent: the source
/// rectangle, and the destination size. Initially both are unset, that
/// is, no scaling is applied. The whole of the current wl_buffer is
/// used as the source, and the surface size is as defined in
/// wl_surface.attach.
///
/// If the destination size is set, it causes the surface size to become
/// dst_width, dst_height. The source (rectangle) is scaled to exactly
/// this size. This overrides whatever the attached wl_buffer size is,
/// unless the wl_buffer is NULL. If the wl_buffer is NULL, the surface
/// has no content and therefore no size. Otherwise, the size is always
/// at least 1x1 in surface local coordinates.
///
/// If the source rectangle is set, it defines what area of the wl_buffer is
/// taken as the source. If the source rectangle is set and the destination
/// size is not set, then src_width and src_height must be integers, and the
/// surface size becomes the source rectangle size. This results in cropping
/// without scaling. If src_width or src_height are not integers and
/// destination size is not set, the bad_size protocol error is raised when
/// the surface state is applied.
///
/// The coordinate transformations from buffer pixel coordinates up to
/// the surface-local coordinates happen in the following order:
/// 1. buffer_transform (wl_surface.set_buffer_transform)
/// 2. buffer_scale (wl_surface.set_buffer_scale)
/// 3. crop and scale (wp_viewport.set*)
/// This means, that the source rectangle coordinates of crop and scale
/// are given in the coordinates after the buffer transform and scale,
/// i.e. in the coordinates that would be the surface-local coordinates
/// if the crop and scale was not applied.
///
/// If src_x or src_y are negative, the bad_value protocol error is raised.
/// Otherwise, if the source rectangle is partially or completely outside of
/// the non-NULL wl_buffer, then the out_of_buffer protocol error is raised
/// when the surface state is applied. A NULL wl_buffer does not raise the
/// out_of_buffer error.
///
/// If the wl_surface associated with the wp_viewport is destroyed,
/// all wp_viewport requests except 'destroy' raise the protocol error
/// no_surface.
///
/// If the wp_viewport object is destroyed, the crop and scale
/// state is removed from the wl_surface. The change will be applied
/// on the next wl_surface.commit.
pub const Viewport = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_viewport",
        .version = 1,
        .request_names = &.{
            "destroy",
            "set_source",
            "set_destination",
        },
    };
    pub const Error = enum(c_int) {
        bad_value = 0,
        bad_size = 1,
        out_of_buffer = 2,
        no_surface = 3,
    };
    pub const Request = union(enum) {
        /// The associated wl_surface's crop and scale state is removed.
        /// The change is applied on the next wl_surface.commit.
        destroy: void,
        /// Set the source rectangle of the associated wl_surface. See
        /// wp_viewport for the description, and relation to the wl_buffer
        /// size.
        ///
        /// If all of x, y, width and height are -1.0, the source rectangle is
        /// unset instead. Any other set of values where width or height are zero
        /// or negative, or x or y are negative, raise the bad_value protocol
        /// error.
        ///
        /// The crop and scale state is double-buffered, see wl_surface.commit.
        set_source: struct {
            x: Fixed, // source rectangle x
            y: Fixed, // source rectangle y
            width: Fixed, // source rectangle width
            height: Fixed, // source rectangle height
        },
        /// Set the destination size of the associated wl_surface. See
        /// wp_viewport for the description, and relation to the wl_buffer
        /// size.
        ///
        /// If width is -1 and height is -1, the destination size is unset
        /// instead. Any other pair of values for width and height that
        /// contains zero or negative values raises the bad_value protocol
        /// error.
        ///
        /// The crop and scale state is double-buffered, see wl_surface.commit.
        set_destination: struct {
            width: i32, // surface width
            height: i32, // surface height
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .set_source => void,
                .set_destination => void,
            };
        }
    };
};

// Copyright © 2022 Kenny Levinsen
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

/// A global interface for requesting surfaces to use fractional scales.
pub const FractionalScaleManagerV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_fractional_scale_manager_v1",
        .version = 1,
        .request_names = &.{
            "destroy",
            "get_fractional_scale",
        },
    };
    pub const Error = enum(c_int) {
        fractional_scale_exists = 0,
    };
    pub const Request = union(enum) {
        /// Informs the server that the client will not be using this protocol
        /// object anymore. This does not affect any other objects,
        /// wp_fractional_scale_v1 objects included.
        destroy: void,
        /// Create an add-on object for the the wl_surface to let the compositor
        /// request fractional scales. If the given wl_surface already has a
        /// wp_fractional_scale_v1 object associated, the fractional_scale_exists
        /// protocol error is raised.
        get_fractional_scale: struct {
            id: FractionalScaleV1 = @enumFromInt(0), // the new surface scale info interface id
            surface: ?wl.Surface, // the surface
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .get_fractional_scale => FractionalScaleV1,
            };
        }
    };
};

/// An additional interface to a wl_surface object which allows the compositor
/// to inform the client of the preferred scale.
pub const FractionalScaleV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_fractional_scale_v1",
        .version = 1,
        .event_signatures = &.{
            &.{.uint},
        },
        .event_names = &.{
            "preferred_scale",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        /// Notification of a new preferred scale for this surface that the
        /// compositor suggests that the client should use.
        ///
        /// The sent scale is the numerator of a fraction with a denominator of 120.
        preferred_scale: struct {
            scale: u32, // the new preferred scale
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .preferred_scale = .{
                        .scale = args[0].uint,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Destroy the fractional scale object. When this object is destroyed,
        /// preferred_scale events will no longer be sent.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
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

const zwp = @import("zwp.zig");
const wl = @import("wl.zig");
