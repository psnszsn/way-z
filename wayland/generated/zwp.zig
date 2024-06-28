// Copyright 2014 © Stephen "Lyude" Chandler Paul
// Copyright 2015-2016 © Red Hat, Inc.
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation files
// (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
//
// The above copyright notice and this permission notice (including the
// next paragraph) shall be included in all copies or substantial
// portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// An object that provides access to the graphics tablets available on this
/// system. All tablets are associated with a seat, to get access to the
/// actual tablets, use wp_tablet_manager.get_tablet_seat.
pub const TabletManagerV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_manager_v2",
        .version = 1,
        .request_names = &.{
            "get_tablet_seat",
            "destroy",
        },
    };
    pub const Request = union(enum) {
        /// Get the wp_tablet_seat object for the given seat. This object
        /// provides access to all graphics tablets in this seat.
        get_tablet_seat: struct {
            tablet_seat: TabletSeatV2 = @enumFromInt(0),
            seat: ?wl.Seat, // The wl_seat object to retrieve the tablets for
        },
        /// Destroy the wp_tablet_manager object. Objects created from this
        /// object are unaffected and should be destroyed separately.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .get_tablet_seat => TabletSeatV2,
                .destroy => void,
            };
        }
    };
};

/// An object that provides access to the graphics tablets available on this
/// seat. After binding to this interface, the compositor sends a set of
/// wp_tablet_seat.tablet_added and wp_tablet_seat.tool_added events.
pub const TabletSeatV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_seat_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.new_id},
            &.{.new_id},
            &.{.new_id},
        },
        .event_names = &.{
            "tablet_added",
            "tool_added",
            "pad_added",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        /// This event is sent whenever a new tablet becomes available on this
        /// seat. This event only provides the object id of the tablet, any
        /// static information about the tablet (device name, vid/pid, etc.) is
        /// sent through the wp_tablet interface.
        tablet_added: void,
        /// This event is sent whenever a tool that has not previously been used
        /// with a tablet comes into use. This event only provides the object id
        /// of the tool; any static information about the tool (capabilities,
        /// type, etc.) is sent through the wp_tablet_tool interface.
        tool_added: void,
        /// This event is sent whenever a new pad is known to the system. Typically,
        /// pads are physically attached to tablets and a pad_added event is
        /// sent immediately after the wp_tablet_seat.tablet_added.
        /// However, some standalone pad devices logically attach to tablets at
        /// runtime, and the client must wait for wp_tablet_pad.enter to know
        /// the tablet a pad is attached to.
        ///
        /// This event only provides the object id of the pad. All further
        /// features (buttons, strips, rings) are sent through the wp_tablet_pad
        /// interface.
        pad_added: void,

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .tablet_added = .{
                        .id = args[0].new_id,
                    },
                },
                1 => Event{
                    .tool_added = .{
                        .id = args[0].new_id,
                    },
                },
                2 => Event{
                    .pad_added = .{
                        .id = args[0].new_id,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Destroy the wp_tablet_seat object. Objects created from this
        /// object are unaffected and should be destroyed separately.
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

/// An object that represents a physical tool that has been, or is
/// currently in use with a tablet in this seat. Each wp_tablet_tool
/// object stays valid until the client destroys it; the compositor
/// reuses the wp_tablet_tool object to indicate that the object's
/// respective physical tool has come into proximity of a tablet again.
///
/// A wp_tablet_tool object's relation to a physical tool depends on the
/// tablet's ability to report serial numbers. If the tablet supports
/// this capability, then the object represents a specific physical tool
/// and can be identified even when used on multiple tablets.
///
/// A tablet tool has a number of static characteristics, e.g. tool type,
/// hardware_serial and capabilities. These capabilities are sent in an
/// event sequence after the wp_tablet_seat.tool_added event before any
/// actual events from this tool. This initial event sequence is
/// terminated by a wp_tablet_tool.done event.
///
/// Tablet tool events are grouped by wp_tablet_tool.frame events.
/// Any events received before a wp_tablet_tool.frame event should be
/// considered part of the same hardware state change.
pub const TabletToolV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_tool_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.uint},
            &.{ .uint, .uint },
            &.{ .uint, .uint },
            &.{.uint},
            &.{},
            &.{},
            &.{ .uint, .object, .object },
            &.{},
            &.{.uint},
            &.{},
            &.{ .fixed, .fixed },
            &.{.uint},
            &.{.uint},
            &.{ .fixed, .fixed },
            &.{.fixed},
            &.{.int},
            &.{ .fixed, .int },
            &.{ .uint, .uint, .uint },
            &.{.uint},
        },
        .event_names = &.{
            "type",
            "hardware_serial",
            "hardware_id_wacom",
            "capability",
            "done",
            "removed",
            "proximity_in",
            "proximity_out",
            "down",
            "up",
            "motion",
            "pressure",
            "distance",
            "tilt",
            "rotation",
            "slider",
            "wheel",
            "button",
            "frame",
        },
        .request_names = &.{
            "set_cursor",
            "destroy",
        },
    };
    pub const Type = enum(c_int) {
        pen = 320,
        eraser = 321,
        brush = 322,
        pencil = 323,
        airbrush = 324,
        finger = 325,
        mouse = 326,
        lens = 327,
    };
    pub const Capability = enum(c_int) {
        tilt = 1,
        pressure = 2,
        distance = 3,
        rotation = 4,
        slider = 5,
        wheel = 6,
    };
    pub const ButtonState = enum(c_int) {
        released = 0,
        pressed = 1,
    };
    pub const Error = enum(c_int) {
        role = 0,
    };
    pub const Event = union(enum) {
        /// The tool type is the high-level type of the tool and usually decides
        /// the interaction expected from this tool.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        type: struct {
            tool_type: Type, // the physical tool type
        },
        /// If the physical tool can be identified by a unique 64-bit serial
        /// number, this event notifies the client of this serial number.
        ///
        /// If multiple tablets are available in the same seat and the tool is
        /// uniquely identifiable by the serial number, that tool may move
        /// between tablets.
        ///
        /// Otherwise, if the tool has no serial number and this event is
        /// missing, the tool is tied to the tablet it first comes into
        /// proximity with. Even if the physical tool is used on multiple
        /// tablets, separate wp_tablet_tool objects will be created, one per
        /// tablet.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        hardware_serial: struct {
            hardware_serial_hi: u32, // the unique serial number of the tool, most significant bits
            hardware_serial_lo: u32, // the unique serial number of the tool, least significant bits
        },
        /// This event notifies the client of a hardware id available on this tool.
        ///
        /// The hardware id is a device-specific 64-bit id that provides extra
        /// information about the tool in use, beyond the wl_tool.type
        /// enumeration. The format of the id is specific to tablets made by
        /// Wacom Inc. For example, the hardware id of a Wacom Grip
        /// Pen (a stylus) is 0x802.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        hardware_id_wacom: struct {
            hardware_id_hi: u32, // the hardware id, most significant bits
            hardware_id_lo: u32, // the hardware id, least significant bits
        },
        /// This event notifies the client of any capabilities of this tool,
        /// beyond the main set of x/y axes and tip up/down detection.
        ///
        /// One event is sent for each extra capability available on this tool.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_tool.done event.
        capability: struct {
            capability: Capability, // the capability
        },
        /// This event signals the end of the initial burst of descriptive
        /// events. A client may consider the static description of the tool to
        /// be complete and finalize initialization of the tool.
        done: void,
        /// This event is sent when the tool is removed from the system and will
        /// send no further events. Should the physical tool come back into
        /// proximity later, a new wp_tablet_tool object will be created.
        ///
        /// It is compositor-dependent when a tool is removed. A compositor may
        /// remove a tool on proximity out, tablet removal or any other reason.
        /// A compositor may also keep a tool alive until shutdown.
        ///
        /// If the tool is currently in proximity, a proximity_out event will be
        /// sent before the removed event. See wp_tablet_tool.proximity_out for
        /// the handling of any buttons logically down.
        ///
        /// When this event is received, the client must wp_tablet_tool.destroy
        /// the object.
        removed: void,
        /// Notification that this tool is focused on a certain surface.
        ///
        /// This event can be received when the tool has moved from one surface to
        /// another, or when the tool has come back into proximity above the
        /// surface.
        ///
        /// If any button is logically down when the tool comes into proximity,
        /// the respective button event is sent after the proximity_in event but
        /// within the same frame as the proximity_in event.
        proximity_in: struct {
            serial: u32,
            tablet: ?TabletV2, // The tablet the tool is in proximity of
            surface: ?wl.Surface, // The current surface the tablet tool is over
        },
        /// Notification that this tool has either left proximity, or is no
        /// longer focused on a certain surface.
        ///
        /// When the tablet tool leaves proximity of the tablet, button release
        /// events are sent for each button that was held down at the time of
        /// leaving proximity. These events are sent before the proximity_out
        /// event but within the same wp_tablet.frame.
        ///
        /// If the tool stays within proximity of the tablet, but the focus
        /// changes from one surface to another, a button release event may not
        /// be sent until the button is actually released or the tool leaves the
        /// proximity of the tablet.
        proximity_out: void,
        /// Sent whenever the tablet tool comes in contact with the surface of the
        /// tablet.
        ///
        /// If the tool is already in contact with the tablet when entering the
        /// input region, the client owning said region will receive a
        /// wp_tablet.proximity_in event, followed by a wp_tablet.down
        /// event and a wp_tablet.frame event.
        ///
        /// Note that this event describes logical contact, not physical
        /// contact. On some devices, a compositor may not consider a tool in
        /// logical contact until a minimum physical pressure threshold is
        /// exceeded.
        down: struct {
            serial: u32,
        },
        /// Sent whenever the tablet tool stops making contact with the surface of
        /// the tablet, or when the tablet tool moves out of the input region
        /// and the compositor grab (if any) is dismissed.
        ///
        /// If the tablet tool moves out of the input region while in contact
        /// with the surface of the tablet and the compositor does not have an
        /// ongoing grab on the surface, the client owning said region will
        /// receive a wp_tablet.up event, followed by a wp_tablet.proximity_out
        /// event and a wp_tablet.frame event. If the compositor has an ongoing
        /// grab on this device, this event sequence is sent whenever the grab
        /// is dismissed in the future.
        ///
        /// Note that this event describes logical contact, not physical
        /// contact. On some devices, a compositor may not consider a tool out
        /// of logical contact until physical pressure falls below a specific
        /// threshold.
        up: void,
        /// Sent whenever a tablet tool moves.
        motion: struct {
            x: Fixed, // surface-local x coordinate
            y: Fixed, // surface-local y coordinate
        },
        /// Sent whenever the pressure axis on a tool changes. The value of this
        /// event is normalized to a value between 0 and 65535.
        ///
        /// Note that pressure may be nonzero even when a tool is not in logical
        /// contact. See the down and up events for more details.
        pressure: struct {
            pressure: u32, // The current pressure value
        },
        /// Sent whenever the distance axis on a tool changes. The value of this
        /// event is normalized to a value between 0 and 65535.
        ///
        /// Note that distance may be nonzero even when a tool is not in logical
        /// contact. See the down and up events for more details.
        distance: struct {
            distance: u32, // The current distance value
        },
        /// Sent whenever one or both of the tilt axes on a tool change. Each tilt
        /// value is in degrees, relative to the z-axis of the tablet.
        /// The angle is positive when the top of a tool tilts along the
        /// positive x or y axis.
        tilt: struct {
            tilt_x: Fixed, // The current value of the X tilt axis
            tilt_y: Fixed, // The current value of the Y tilt axis
        },
        /// Sent whenever the z-rotation axis on the tool changes. The
        /// rotation value is in degrees clockwise from the tool's
        /// logical neutral position.
        rotation: struct {
            degrees: Fixed, // The current rotation of the Z axis
        },
        /// Sent whenever the slider position on the tool changes. The
        /// value is normalized between -65535 and 65535, with 0 as the logical
        /// neutral position of the slider.
        ///
        /// The slider is available on e.g. the Wacom Airbrush tool.
        slider: struct {
            position: i32, // The current position of slider
        },
        /// Sent whenever the wheel on the tool emits an event. This event
        /// contains two values for the same axis change. The degrees value is
        /// in the same orientation as the wl_pointer.vertical_scroll axis. The
        /// clicks value is in discrete logical clicks of the mouse wheel. This
        /// value may be zero if the movement of the wheel was less
        /// than one logical click.
        ///
        /// Clients should choose either value and avoid mixing degrees and
        /// clicks. The compositor may accumulate values smaller than a logical
        /// click and emulate click events when a certain threshold is met.
        /// Thus, wl_tablet_tool.wheel events with non-zero clicks values may
        /// have different degrees values.
        wheel: struct {
            degrees: Fixed, // The wheel delta in degrees
            clicks: i32, // The wheel delta in discrete clicks
        },
        /// Sent whenever a button on the tool is pressed or released.
        ///
        /// If a button is held down when the tool moves in or out of proximity,
        /// button events are generated by the compositor. See
        /// wp_tablet_tool.proximity_in and wp_tablet_tool.proximity_out for
        /// details.
        button: struct {
            serial: u32,
            button: u32, // The button whose state has changed
            state: ButtonState, // Whether the button was pressed or released
        },
        /// Marks the end of a series of axis and/or button updates from the
        /// tablet. The Wayland protocol requires axis updates to be sent
        /// sequentially, however all events within a frame should be considered
        /// one hardware event.
        frame: struct {
            time: u32, // The time of the event with millisecond granularity
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .type = .{
                        .tool_type = @enumFromInt(args[0].uint),
                    },
                },
                1 => Event{
                    .hardware_serial = .{
                        .hardware_serial_hi = args[0].uint,
                        .hardware_serial_lo = args[1].uint,
                    },
                },
                2 => Event{
                    .hardware_id_wacom = .{
                        .hardware_id_hi = args[0].uint,
                        .hardware_id_lo = args[1].uint,
                    },
                },
                3 => Event{
                    .capability = .{
                        .capability = @enumFromInt(args[0].uint),
                    },
                },
                4 => Event.done,
                5 => Event.removed,
                6 => Event{
                    .proximity_in = .{
                        .serial = args[0].uint,
                        .tablet = @enumFromInt(args[1].object),
                        .surface = @enumFromInt(args[2].object),
                    },
                },
                7 => Event.proximity_out,
                8 => Event{
                    .down = .{
                        .serial = args[0].uint,
                    },
                },
                9 => Event.up,
                10 => Event{
                    .motion = .{
                        .x = args[0].fixed,
                        .y = args[1].fixed,
                    },
                },
                11 => Event{
                    .pressure = .{
                        .pressure = args[0].uint,
                    },
                },
                12 => Event{
                    .distance = .{
                        .distance = args[0].uint,
                    },
                },
                13 => Event{
                    .tilt = .{
                        .tilt_x = args[0].fixed,
                        .tilt_y = args[1].fixed,
                    },
                },
                14 => Event{
                    .rotation = .{
                        .degrees = args[0].fixed,
                    },
                },
                15 => Event{
                    .slider = .{
                        .position = args[0].int,
                    },
                },
                16 => Event{
                    .wheel = .{
                        .degrees = args[0].fixed,
                        .clicks = args[1].int,
                    },
                },
                17 => Event{
                    .button = .{
                        .serial = args[0].uint,
                        .button = args[1].uint,
                        .state = @enumFromInt(args[2].uint),
                    },
                },
                18 => Event{
                    .frame = .{
                        .time = args[0].uint,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Sets the surface of the cursor used for this tool on the given
        /// tablet. This request only takes effect if the tool is in proximity
        /// of one of the requesting client's surfaces or the surface parameter
        /// is the current pointer surface. If there was a previous surface set
        /// with this request it is replaced. If surface is NULL, the cursor
        /// image is hidden.
        ///
        /// The parameters hotspot_x and hotspot_y define the position of the
        /// pointer surface relative to the pointer location. Its top-left corner
        /// is always at (x, y) - (hotspot_x, hotspot_y), where (x, y) are the
        /// coordinates of the pointer location, in surface-local coordinates.
        ///
        /// On surface.attach requests to the pointer surface, hotspot_x and
        /// hotspot_y are decremented by the x and y parameters passed to the
        /// request. Attach must be confirmed by wl_surface.commit as usual.
        ///
        /// The hotspot can also be updated by passing the currently set pointer
        /// surface to this request with new values for hotspot_x and hotspot_y.
        ///
        /// The current and pending input regions of the wl_surface are cleared,
        /// and wl_surface.set_input_region is ignored until the wl_surface is no
        /// longer used as the cursor. When the use as a cursor ends, the current
        /// and pending input regions become undefined, and the wl_surface is
        /// unmapped.
        ///
        /// This request gives the surface the role of a wp_tablet_tool cursor. A
        /// surface may only ever be used as the cursor surface for one
        /// wp_tablet_tool. If the surface already has another role or has
        /// previously been used as cursor surface for a different tool, a
        /// protocol error is raised.
        set_cursor: struct {
            serial: u32, // serial of the proximity_in event
            surface: ?wl.Surface,
            hotspot_x: i32, // surface-local x coordinate
            hotspot_y: i32, // surface-local y coordinate
        },
        /// This destroys the client's resource for this tool object.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .set_cursor => void,
                .destroy => void,
            };
        }
    };
};

/// The wp_tablet interface represents one graphics tablet device. The
/// tablet interface itself does not generate events; all events are
/// generated by wp_tablet_tool objects when in proximity above a tablet.
///
/// A tablet has a number of static characteristics, e.g. device name and
/// pid/vid. These capabilities are sent in an event sequence after the
/// wp_tablet_seat.tablet_added event. This initial event sequence is
/// terminated by a wp_tablet.done event.
pub const TabletV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.string},
            &.{ .uint, .uint },
            &.{.string},
            &.{},
            &.{},
        },
        .event_names = &.{
            "name",
            "id",
            "path",
            "done",
            "removed",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        /// A descriptive name for the tablet device.
        ///
        /// If the device has no descriptive name, this event is not sent.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        name: struct {
            name: [:0]const u8, // the device name
        },
        /// The USB vendor and product IDs for the tablet device.
        ///
        /// If the device has no USB vendor/product ID, this event is not sent.
        /// This can happen for virtual devices or non-USB devices, for instance.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        id: struct {
            vid: u32, // USB vendor id
            pid: u32, // USB product id
        },
        /// A system-specific device path that indicates which device is behind
        /// this wp_tablet. This information may be used to gather additional
        /// information about the device, e.g. through libwacom.
        ///
        /// A device may have more than one device path. If so, multiple
        /// wp_tablet.path events are sent. A device may be emulated and not
        /// have a device path, and in that case this event will not be sent.
        ///
        /// The format of the path is unspecified, it may be a device node, a
        /// sysfs path, or some other identifier. It is up to the client to
        /// identify the string provided.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet.done event.
        path: struct {
            path: [:0]const u8, // path to local device
        },
        /// This event is sent immediately to signal the end of the initial
        /// burst of descriptive events. A client may consider the static
        /// description of the tablet to be complete and finalize initialization
        /// of the tablet.
        done: void,
        /// Sent when the tablet has been removed from the system. When a tablet
        /// is removed, some tools may be removed.
        ///
        /// When this event is received, the client must wp_tablet.destroy
        /// the object.
        removed: void,

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .name = .{
                        .name = args[0].string,
                    },
                },
                1 => Event{
                    .id = .{
                        .vid = args[0].uint,
                        .pid = args[1].uint,
                    },
                },
                2 => Event{
                    .path = .{
                        .path = args[0].string,
                    },
                },
                3 => Event.done,
                4 => Event.removed,
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// This destroys the client's resource for this tablet object.
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

/// A circular interaction area, such as the touch ring on the Wacom Intuos
/// Pro series tablets.
///
/// Events on a ring are logically grouped by the wl_tablet_pad_ring.frame
/// event.
pub const TabletPadRingV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_pad_ring_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.uint},
            &.{.fixed},
            &.{},
            &.{.uint},
        },
        .event_names = &.{
            "source",
            "angle",
            "stop",
            "frame",
        },
        .request_names = &.{
            "set_feedback",
            "destroy",
        },
    };
    pub const Source = enum(c_int) {
        finger = 1,
    };
    pub const Event = union(enum) {
        /// Source information for ring events.
        ///
        /// This event does not occur on its own. It is sent before a
        /// wp_tablet_pad_ring.frame event and carries the source information
        /// for all events within that frame.
        ///
        /// The source specifies how this event was generated. If the source is
        /// wp_tablet_pad_ring.source.finger, a wp_tablet_pad_ring.stop event
        /// will be sent when the user lifts the finger off the device.
        ///
        /// This event is optional. If the source is unknown for an interaction,
        /// no event is sent.
        source: struct {
            source: Source, // the event source
        },
        /// Sent whenever the angle on a ring changes.
        ///
        /// The angle is provided in degrees clockwise from the logical
        /// north of the ring in the pad's current rotation.
        angle: struct {
            degrees: Fixed, // the current angle in degrees
        },
        /// Stop notification for ring events.
        ///
        /// For some wp_tablet_pad_ring.source types, a wp_tablet_pad_ring.stop
        /// event is sent to notify a client that the interaction with the ring
        /// has terminated. This enables the client to implement kinetic scrolling.
        /// See the wp_tablet_pad_ring.source documentation for information on
        /// when this event may be generated.
        ///
        /// Any wp_tablet_pad_ring.angle events with the same source after this
        /// event should be considered as the start of a new interaction.
        stop: void,
        /// Indicates the end of a set of ring events that logically belong
        /// together. A client is expected to accumulate the data in all events
        /// within the frame before proceeding.
        ///
        /// All wp_tablet_pad_ring events before a wp_tablet_pad_ring.frame event belong
        /// logically together. For example, on termination of a finger interaction
        /// on a ring the compositor will send a wp_tablet_pad_ring.source event,
        /// a wp_tablet_pad_ring.stop event and a wp_tablet_pad_ring.frame event.
        ///
        /// A wp_tablet_pad_ring.frame event is sent for every logical event
        /// group, even if the group only contains a single wp_tablet_pad_ring
        /// event. Specifically, a client may get a sequence: angle, frame,
        /// angle, frame, etc.
        frame: struct {
            time: u32, // timestamp with millisecond granularity
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .source = .{
                        .source = @enumFromInt(args[0].uint),
                    },
                },
                1 => Event{
                    .angle = .{
                        .degrees = args[0].fixed,
                    },
                },
                2 => Event.stop,
                3 => Event{
                    .frame = .{
                        .time = args[0].uint,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Request that the compositor use the provided feedback string
        /// associated with this ring. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever the ring is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        ///
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with the ring; compositors may use this
        /// information to offer visual feedback about the button layout
        /// (eg. on-screen displays).
        ///
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        ///
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// ring. Requests providing other serials than the most recent one will be
        /// ignored.
        set_feedback: struct {
            description: [:0]const u8, // ring description
            serial: u32, // serial of the mode switch event
        },
        /// This destroys the client's resource for this ring object.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .set_feedback => void,
                .destroy => void,
            };
        }
    };
};

/// A linear interaction area, such as the strips found in Wacom Cintiq
/// models.
///
/// Events on a strip are logically grouped by the wl_tablet_pad_strip.frame
/// event.
pub const TabletPadStripV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_pad_strip_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.uint},
            &.{.uint},
            &.{},
            &.{.uint},
        },
        .event_names = &.{
            "source",
            "position",
            "stop",
            "frame",
        },
        .request_names = &.{
            "set_feedback",
            "destroy",
        },
    };
    pub const Source = enum(c_int) {
        finger = 1,
    };
    pub const Event = union(enum) {
        /// Source information for strip events.
        ///
        /// This event does not occur on its own. It is sent before a
        /// wp_tablet_pad_strip.frame event and carries the source information
        /// for all events within that frame.
        ///
        /// The source specifies how this event was generated. If the source is
        /// wp_tablet_pad_strip.source.finger, a wp_tablet_pad_strip.stop event
        /// will be sent when the user lifts their finger off the device.
        ///
        /// This event is optional. If the source is unknown for an interaction,
        /// no event is sent.
        source: struct {
            source: Source, // the event source
        },
        /// Sent whenever the position on a strip changes.
        ///
        /// The position is normalized to a range of [0, 65535], the 0-value
        /// represents the top-most and/or left-most position of the strip in
        /// the pad's current rotation.
        position: struct {
            position: u32, // the current position
        },
        /// Stop notification for strip events.
        ///
        /// For some wp_tablet_pad_strip.source types, a wp_tablet_pad_strip.stop
        /// event is sent to notify a client that the interaction with the strip
        /// has terminated. This enables the client to implement kinetic
        /// scrolling. See the wp_tablet_pad_strip.source documentation for
        /// information on when this event may be generated.
        ///
        /// Any wp_tablet_pad_strip.position events with the same source after this
        /// event should be considered as the start of a new interaction.
        stop: void,
        /// Indicates the end of a set of events that represent one logical
        /// hardware strip event. A client is expected to accumulate the data
        /// in all events within the frame before proceeding.
        ///
        /// All wp_tablet_pad_strip events before a wp_tablet_pad_strip.frame event belong
        /// logically together. For example, on termination of a finger interaction
        /// on a strip the compositor will send a wp_tablet_pad_strip.source event,
        /// a wp_tablet_pad_strip.stop event and a wp_tablet_pad_strip.frame
        /// event.
        ///
        /// A wp_tablet_pad_strip.frame event is sent for every logical event
        /// group, even if the group only contains a single wp_tablet_pad_strip
        /// event. Specifically, a client may get a sequence: position, frame,
        /// position, frame, etc.
        frame: struct {
            time: u32, // timestamp with millisecond granularity
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .source = .{
                        .source = @enumFromInt(args[0].uint),
                    },
                },
                1 => Event{
                    .position = .{
                        .position = args[0].uint,
                    },
                },
                2 => Event.stop,
                3 => Event{
                    .frame = .{
                        .time = args[0].uint,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Requests the compositor to use the provided feedback string
        /// associated with this strip. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever the strip is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        ///
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with the strip, and compositors may use this
        /// information to offer visual feedback about the button layout
        /// (eg. on-screen displays).
        ///
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        ///
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// strip. Requests providing other serials than the most recent one will be
        /// ignored.
        set_feedback: struct {
            description: [:0]const u8, // strip description
            serial: u32, // serial of the mode switch event
        },
        /// This destroys the client's resource for this strip object.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .set_feedback => void,
                .destroy => void,
            };
        }
    };
};

/// A pad group describes a distinct (sub)set of buttons, rings and strips
/// present in the tablet. The criteria of this grouping is usually positional,
/// eg. if a tablet has buttons on the left and right side, 2 groups will be
/// presented. The physical arrangement of groups is undisclosed and may
/// change on the fly.
///
/// Pad groups will announce their features during pad initialization. Between
/// the corresponding wp_tablet_pad.group event and wp_tablet_pad_group.done, the
/// pad group will announce the buttons, rings and strips contained in it,
/// plus the number of supported modes.
///
/// Modes are a mechanism to allow multiple groups of actions for every element
/// in the pad group. The number of groups and available modes in each is
/// persistent across device plugs. The current mode is user-switchable, it
/// will be announced through the wp_tablet_pad_group.mode_switch event both
/// whenever it is switched, and after wp_tablet_pad.enter.
///
/// The current mode logically applies to all elements in the pad group,
/// although it is at clients' discretion whether to actually perform different
/// actions, and/or issue the respective .set_feedback requests to notify the
/// compositor. See the wp_tablet_pad_group.mode_switch event for more details.
pub const TabletPadGroupV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_pad_group_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.array},
            &.{.new_id},
            &.{.new_id},
            &.{.uint},
            &.{},
            &.{ .uint, .uint, .uint },
        },
        .event_names = &.{
            "buttons",
            "ring",
            "strip",
            "modes",
            "done",
            "mode_switch",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        /// Sent on wp_tablet_pad_group initialization to announce the available
        /// buttons in the group. Button indices start at 0, a button may only be
        /// in one group at a time.
        ///
        /// This event is first sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        ///
        /// Some buttons are reserved by the compositor. These buttons may not be
        /// assigned to any wp_tablet_pad_group. Compositors may broadcast this
        /// event in the case of changes to the mapping of these reserved buttons.
        /// If the compositor happens to reserve all buttons in a group, this event
        /// will be sent with an empty array.
        buttons: struct {
            buttons: []u8, // buttons in this group
        },
        /// Sent on wp_tablet_pad_group initialization to announce available rings.
        /// One event is sent for each ring available on this pad group.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        ring: void,
        /// Sent on wp_tablet_pad initialization to announce available strips.
        /// One event is sent for each strip available on this pad group.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event.
        strip: void,
        /// Sent on wp_tablet_pad_group initialization to announce that the pad
        /// group may switch between modes. A client may use a mode to store a
        /// specific configuration for buttons, rings and strips and use the
        /// wl_tablet_pad_group.mode_switch event to toggle between these
        /// configurations. Mode indices start at 0.
        ///
        /// Switching modes is compositor-dependent. See the
        /// wp_tablet_pad_group.mode_switch event for more details.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad_group.done event. This event is only sent when more than
        /// more than one mode is available.
        modes: struct {
            modes: u32, // the number of modes
        },
        /// This event is sent immediately to signal the end of the initial
        /// burst of descriptive events. A client may consider the static
        /// description of the tablet to be complete and finalize initialization
        /// of the tablet group.
        done: void,
        /// Notification that the mode was switched.
        ///
        /// A mode applies to all buttons, rings and strips in a group
        /// simultaneously, but a client is not required to assign different actions
        /// for each mode. For example, a client may have mode-specific button
        /// mappings but map the ring to vertical scrolling in all modes. Mode
        /// indices start at 0.
        ///
        /// Switching modes is compositor-dependent. The compositor may provide
        /// visual cues to the client about the mode, e.g. by toggling LEDs on
        /// the tablet device. Mode-switching may be software-controlled or
        /// controlled by one or more physical buttons. For example, on a Wacom
        /// Intuos Pro, the button inside the ring may be assigned to switch
        /// between modes.
        ///
        /// The compositor will also send this event after wp_tablet_pad.enter on
        /// each group in order to notify of the current mode. Groups that only
        /// feature one mode will use mode=0 when emitting this event.
        ///
        /// If a button action in the new mode differs from the action in the
        /// previous mode, the client should immediately issue a
        /// wp_tablet_pad.set_feedback request for each changed button.
        ///
        /// If a ring or strip action in the new mode differs from the action
        /// in the previous mode, the client should immediately issue a
        /// wp_tablet_ring.set_feedback or wp_tablet_strip.set_feedback request
        /// for each changed ring or strip.
        mode_switch: struct {
            time: u32, // the time of the event with millisecond granularity
            serial: u32,
            mode: u32, // the new mode of the pad
        },

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .buttons = .{
                        .buttons = args[0].array.slice(u8),
                    },
                },
                1 => Event{
                    .ring = .{
                        .ring = args[0].new_id,
                    },
                },
                2 => Event{
                    .strip = .{
                        .strip = args[0].new_id,
                    },
                },
                3 => Event{
                    .modes = .{
                        .modes = args[0].uint,
                    },
                },
                4 => Event.done,
                5 => Event{
                    .mode_switch = .{
                        .time = args[0].uint,
                        .serial = args[1].uint,
                        .mode = args[2].uint,
                    },
                },
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Destroy the wp_tablet_pad_group object. Objects created from this object
        /// are unaffected and should be destroyed separately.
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

/// A pad device is a set of buttons, rings and strips
/// usually physically present on the tablet device itself. Some
/// exceptions exist where the pad device is physically detached, e.g. the
/// Wacom ExpressKey Remote.
///
/// Pad devices have no axes that control the cursor and are generally
/// auxiliary devices to the tool devices used on the tablet surface.
///
/// A pad device has a number of static characteristics, e.g. the number
/// of rings. These capabilities are sent in an event sequence after the
/// wp_tablet_seat.pad_added event before any actual events from this pad.
/// This initial event sequence is terminated by a wp_tablet_pad.done
/// event.
///
/// All pad features (buttons, rings and strips) are logically divided into
/// groups and all pads have at least one group. The available groups are
/// notified through the wp_tablet_pad.group event; the compositor will
/// emit one event per group before emitting wp_tablet_pad.done.
///
/// Groups may have multiple modes. Modes allow clients to map multiple
/// actions to a single pad feature. Only one mode can be active per group,
/// although different groups may have different active modes.
pub const TabletPadV2 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_tablet_pad_v2",
        .version = 1,
        .event_signatures = &.{
            &.{.new_id},
            &.{.string},
            &.{.uint},
            &.{},
            &.{ .uint, .uint, .uint },
            &.{ .uint, .object, .object },
            &.{ .uint, .object },
            &.{},
        },
        .event_names = &.{
            "group",
            "path",
            "buttons",
            "done",
            "button",
            "enter",
            "leave",
            "removed",
        },
        .request_names = &.{
            "set_feedback",
            "destroy",
        },
    };
    pub const ButtonState = enum(c_int) {
        released = 0,
        pressed = 1,
    };
    pub const Event = union(enum) {
        /// Sent on wp_tablet_pad initialization to announce available groups.
        /// One event is sent for each pad group available.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event. At least one group will be announced.
        group: void,
        /// A system-specific device path that indicates which device is behind
        /// this wp_tablet_pad. This information may be used to gather additional
        /// information about the device, e.g. through libwacom.
        ///
        /// The format of the path is unspecified, it may be a device node, a
        /// sysfs path, or some other identifier. It is up to the client to
        /// identify the string provided.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event.
        path: struct {
            path: [:0]const u8, // path to local device
        },
        /// Sent on wp_tablet_pad initialization to announce the available
        /// buttons.
        ///
        /// This event is sent in the initial burst of events before the
        /// wp_tablet_pad.done event. This event is only sent when at least one
        /// button is available.
        buttons: struct {
            buttons: u32, // the number of buttons
        },
        /// This event signals the end of the initial burst of descriptive
        /// events. A client may consider the static description of the pad to
        /// be complete and finalize initialization of the pad.
        done: void,
        /// Sent whenever the physical state of a button changes.
        button: struct {
            time: u32, // the time of the event with millisecond granularity
            button: u32, // the index of the button that changed state
            state: ButtonState,
        },
        /// Notification that this pad is focused on the specified surface.
        enter: struct {
            serial: u32, // serial number of the enter event
            tablet: ?TabletV2, // the tablet the pad is attached to
            surface: ?wl.Surface, // surface the pad is focused on
        },
        /// Notification that this pad is no longer focused on the specified
        /// surface.
        leave: struct {
            serial: u32, // serial number of the leave event
            surface: ?wl.Surface, // surface the pad is no longer focused on
        },
        /// Sent when the pad has been removed from the system. When a tablet
        /// is removed its pad(s) will be removed too.
        ///
        /// When this event is received, the client must destroy all rings, strips
        /// and groups that were offered by this pad, and issue wp_tablet_pad.destroy
        /// the pad itself.
        removed: void,

        pub fn from_args(
            opcode: u16,
            args: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event{
                    .group = .{
                        .pad_group = args[0].new_id,
                    },
                },
                1 => Event{
                    .path = .{
                        .path = args[0].string,
                    },
                },
                2 => Event{
                    .buttons = .{
                        .buttons = args[0].uint,
                    },
                },
                3 => Event.done,
                4 => Event{
                    .button = .{
                        .time = args[0].uint,
                        .button = args[1].uint,
                        .state = @enumFromInt(args[2].uint),
                    },
                },
                5 => Event{
                    .enter = .{
                        .serial = args[0].uint,
                        .tablet = @enumFromInt(args[1].object),
                        .surface = @enumFromInt(args[2].object),
                    },
                },
                6 => Event{
                    .leave = .{
                        .serial = args[0].uint,
                        .surface = @enumFromInt(args[1].object),
                    },
                },
                7 => Event.removed,
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Requests the compositor to use the provided feedback string
        /// associated with this button. This request should be issued immediately
        /// after a wp_tablet_pad_group.mode_switch event from the corresponding
        /// group is received, or whenever a button is mapped to a different
        /// action. See wp_tablet_pad_group.mode_switch for more details.
        ///
        /// Clients are encouraged to provide context-aware descriptions for
        /// the actions associated with each button, and compositors may use
        /// this information to offer visual feedback on the button layout
        /// (e.g. on-screen displays).
        ///
        /// Button indices start at 0. Setting the feedback string on a button
        /// that is reserved by the compositor (i.e. not belonging to any
        /// wp_tablet_pad_group) does not generate an error but the compositor
        /// is free to ignore the request.
        ///
        /// The provided string 'description' is a UTF-8 encoded string to be
        /// associated with this ring, and is considered user-visible; general
        /// internationalization rules apply.
        ///
        /// The serial argument will be that of the last
        /// wp_tablet_pad_group.mode_switch event received for the group of this
        /// button. Requests providing other serials than the most recent one will
        /// be ignored.
        set_feedback: struct {
            button: u32, // button index
            description: [:0]const u8, // button description
            serial: u32, // serial of the mode switch event
        },
        /// Destroy the wp_tablet_pad object. Objects created from this object
        /// are unaffected and should be destroyed separately.
        destroy: void,

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .set_feedback => void,
                .destroy => void,
            };
        }
    };
};

// Copyright © 2017 Red Hat Inc.
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

/// A global interface used for inhibiting the compositor keyboard shortcuts.
pub const KeyboardShortcutsInhibitManagerV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_keyboard_shortcuts_inhibit_manager_v1",
        .version = 1,
        .request_names = &.{
            "destroy",
            "inhibit_shortcuts",
        },
    };
    pub const Error = enum(c_int) {
        already_inhibited = 0,
    };
    pub const Request = union(enum) {
        /// Destroy the keyboard shortcuts inhibitor manager.
        destroy: void,
        /// Create a new keyboard shortcuts inhibitor object associated with
        /// the given surface for the given seat.
        ///
        /// If shortcuts are already inhibited for the specified seat and surface,
        /// a protocol error "already_inhibited" is raised by the compositor.
        inhibit_shortcuts: struct {
            id: KeyboardShortcutsInhibitorV1 = @enumFromInt(0),
            surface: ?wl.Surface, // the surface that inhibits the keyboard shortcuts behavior
            seat: ?wl.Seat, // the wl_seat for which keyboard shortcuts should be disabled
        },

        pub fn ReturnType(
            request: std.meta.Tag(Request),
        ) type {
            return switch (request) {
                .destroy => void,
                .inhibit_shortcuts => KeyboardShortcutsInhibitorV1,
            };
        }
    };
};

/// A keyboard shortcuts inhibitor instructs the compositor to ignore
/// its own keyboard shortcuts when the associated surface has keyboard
/// focus. As a result, when the surface has keyboard focus on the given
/// seat, it will receive all key events originating from the specified
/// seat, even those which would normally be caught by the compositor for
/// its own shortcuts.
///
/// The Wayland compositor is however under no obligation to disable
/// all of its shortcuts, and may keep some special key combo for its own
/// use, including but not limited to one allowing the user to forcibly
/// restore normal keyboard events routing in the case of an unwilling
/// client. The compositor may also use the same key combo to reactivate
/// an existing shortcut inhibitor that was previously deactivated on
/// user request.
///
/// When the compositor restores its own keyboard shortcuts, an
/// "inactive" event is emitted to notify the client that the keyboard
/// shortcuts inhibitor is not effectively active for the surface and
/// seat any more, and the client should not expect to receive all
/// keyboard events.
///
/// When the keyboard shortcuts inhibitor is inactive, the client has
/// no way to forcibly reactivate the keyboard shortcuts inhibitor.
///
/// The user can chose to re-enable a previously deactivated keyboard
/// shortcuts inhibitor using any mechanism the compositor may offer,
/// in which case the compositor will send an "active" event to notify
/// the client.
///
/// If the surface is destroyed, unmapped, or loses the seat's keyboard
/// focus, the keyboard shortcuts inhibitor becomes irrelevant and the
/// compositor will restore its own keyboard shortcuts but no "inactive"
/// event is emitted in this case.
pub const KeyboardShortcutsInhibitorV1 = enum(u32) {
    _,
    pub const interface = Interface{
        .name = "zwp_keyboard_shortcuts_inhibitor_v1",
        .version = 1,
        .event_signatures = &.{
            &.{},
            &.{},
        },
        .event_names = &.{
            "active",
            "inactive",
        },
        .request_names = &.{
            "destroy",
        },
    };
    pub const Event = union(enum) {
        /// This event indicates that the shortcut inhibitor is active.
        ///
        /// The compositor sends this event every time compositor shortcuts
        /// are inhibited on behalf of the surface. When active, the client
        /// may receive input events normally reserved by the compositor
        /// (see zwp_keyboard_shortcuts_inhibitor_v1).
        ///
        /// This occurs typically when the initial request "inhibit_shortcuts"
        /// first becomes active or when the user instructs the compositor to
        /// re-enable and existing shortcuts inhibitor using any mechanism
        /// offered by the compositor.
        active: void,
        /// This event indicates that the shortcuts inhibitor is inactive,
        /// normal shortcuts processing is restored by the compositor.
        inactive: void,

        pub fn from_args(
            opcode: u16,
            _: []Argument,
        ) Event {
            return switch (opcode) {
                0 => Event.active,
                1 => Event.inactive,
                else => unreachable,
            };
        }
    };
    pub const Request = union(enum) {
        /// Remove the keyboard shortcuts inhibitor from the associated wl_surface.
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

const wl = @import("wl.zig");
