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
const std = @import("std");
const os = std.os;
const Proxy = @import("../proxy.zig").Proxy;
const Interface = @import("../proxy.zig").Interface;
const Argument = @import("../argument.zig").Argument;
const Fixed = @import("../argument.zig").Fixed;
const Client = @import("../client.zig").Client;

const wl = @import("wl.zig");
const zwp = @import("zwp.zig");

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
        .version = 1,
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
        get_pointer: struct {
            pointer: ?wl.Pointer,
        },
        /// Obtain a wp_cursor_shape_device_v1 for a zwp_tablet_tool_v2 object.
        get_tablet_tool_v2: struct {
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

/// This interface advertises the list of supported cursor shapes for a
/// device, and allows clients to set the cursor shape.
pub const CursorShapeDeviceV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "wp_cursor_shape_device_v1",
        .version = 1,
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
