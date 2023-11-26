const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const fmtId = std.zig.fmtId;

const log = std.log.scoped(.@"zig-wayland");

const xml = @import("xml.zig");

const gpa = general_purpose_allocator.allocator();
var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};

/// All data in this struct is immutable after creation in parse().
const Protocol = struct {
    const Global = struct {
        interface: Interface,
        children: []const Interface,
    };

    name: []const u8,
    namespace: []const u8,
    copyright: ?[]const u8,
    toplevel_description: ?[]const u8,

    version_locked_interfaces: []const Interface,
    globals: []const Global,

    fn parseXML(arena: mem.Allocator, xml_bytes: []const u8) !Protocol {
        var parser = xml.Parser.init(xml_bytes);
        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| if (mem.eql(u8, tag, "protocol")) return parse(arena, &parser),
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Protocol {
        var name: ?[]const u8 = null;
        var copyright: ?[]const u8 = null;
        var toplevel_description: ?[]const u8 = null;
        var version_locked_interfaces = std.ArrayList(Interface).init(gpa);
        defer version_locked_interfaces.deinit();
        var interfaces = std.StringArrayHashMap(Interface).init(gpa);
        defer interfaces.deinit();

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                if (mem.eql(u8, tag, "copyright")) {
                    if (copyright != null)
                        return error.DuplicateCopyright;
                    const e = parser.next() orelse return error.UnexpectedEndOfFile;
                    switch (e) {
                        .character_data => |data| copyright = try arena.dupe(u8, data),
                        else => return error.BadCopyright,
                    }
                } else if (mem.eql(u8, tag, "description")) {
                    if (toplevel_description != null)
                        return error.DuplicateToplevelDescription;
                    while (parser.next()) |e| {
                        switch (e) {
                            .character_data => |data| {
                                toplevel_description = try arena.dupe(u8, data);
                                break;
                            },
                            .attribute => continue,
                            else => return error.BadToplevelDescription,
                        }
                    } else {
                        return error.UnexpectedEndOfFile;
                    }
                } else if (mem.eql(u8, tag, "interface")) {
                    const interface = try Interface.parse(arena, parser);
                    if (Interface.version_locked(interface.name)) {
                        try version_locked_interfaces.append(interface);
                    } else {
                        const gop = try interfaces.getOrPut(interface.name);
                        if (gop.found_existing) return error.DuplicateInterfaceName;
                        gop.value_ptr.* = interface;
                    }
                }
            },
            .attribute => |attr| if (mem.eql(u8, attr.name, "name")) {
                if (name != null) return error.DuplicateName;
                name = try attr.dupeValue(arena);
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "protocol")) {
                if (interfaces.count() == 0) return error.NoInterfaces;

                const globals = try find_globals(arena, interfaces);
                if (globals.len == 0) return error.NoGlobals;

                const namespace = prefix(interfaces.values()[0].name) orelse return error.NoNamespace;
                for (interfaces.values()) |interface| {
                    const other = prefix(interface.name) orelse return error.NoNamespace;
                    if (!mem.eql(u8, namespace, other)) return error.InconsistentNamespaces;
                }

                return Protocol{
                    .name = name orelse return error.MissingName,
                    .namespace = namespace,

                    // Missing copyright or toplevel description is bad style, but not illegal.
                    .copyright = copyright,
                    .toplevel_description = toplevel_description,
                    .version_locked_interfaces = try arena.dupe(Interface, version_locked_interfaces.items),
                    .globals = globals,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn find_globals(arena: mem.Allocator, interfaces: std.StringArrayHashMap(Interface)) ![]const Global {
        var non_globals = std.StringHashMap(void).init(gpa);
        defer non_globals.deinit();

        for (interfaces.values()) |interface| {
            assert(!Interface.version_locked(interface.name));
            for (interface.requests) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_interface_name| {
                        try non_globals.put(child_interface_name, {});
                    }
                }
            }
            for (interface.events) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_interface_name| {
                        try non_globals.put(child_interface_name, {});
                    }
                }
            }
        }

        var globals = std.ArrayList(Global).init(gpa);
        defer globals.deinit();

        for (interfaces.values()) |interface| {
            if (!non_globals.contains(interface.name)) {
                var children = std.StringArrayHashMap(Interface).init(gpa);
                defer children.deinit();

                try find_children(interface, interfaces, &children);

                try globals.append(.{
                    .interface = interface,
                    .children = try arena.dupe(Interface, children.values()),
                });
            }
        }

        return arena.dupe(Global, globals.items);
    }

    fn find_children(
        parent: Interface,
        interfaces: std.StringArrayHashMap(Interface),
        children: *std.StringArrayHashMap(Interface),
    ) error{ OutOfMemory, InvalidInterface }!void {
        for ([_][]const Message{ parent.requests, parent.events }) |messages| {
            for (messages) |message| {
                if (message.kind == .constructor) {
                    if (message.kind.constructor) |child_name| {
                        if (Interface.version_locked(child_name)) continue;

                        const child = interfaces.get(child_name) orelse {
                            log.err("interface '{s}' constructed by message '{s}' not defined in the protocol and not wl_callback or wl_buffer", .{
                                child_name,
                                message.name,
                            });
                            return error.InvalidInterface;
                        };
                        try children.put(child_name, child);
                        try find_children(child, interfaces, children);
                    }
                }
            }
        }
    }

    fn emitCopyrightAndToplevelDescription(protocol: Protocol, writer: anytype) !void {
        try writer.writeAll("// Generated by zig-wayland-2\n\n");
        if (protocol.copyright) |copyright| {
            var it = mem.split(u8, copyright, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.whitespace)});
            }
            try writer.writeByte('\n');
        }
        if (protocol.toplevel_description) |toplevel_description| {
            var it = mem.split(u8, toplevel_description, "\n");
            while (it.next()) |line| {
                try writer.print("// {s}\n", .{mem.trim(u8, line, &std.ascii.whitespace)});
            }
            try writer.writeByte('\n');
        }
    }

    fn emit(protocol: Protocol, writer: anytype) !void {
        try protocol.emitCopyrightAndToplevelDescription(writer);
        const side = .client;
        _ = side;
        try writer.writeAll(
            \\const std = @import("std");
            \\const os = std.os;
            \\const Proxy = @import("proxy.zig").Proxy;
            \\const Argument = @import("argument.zig").Argument;
            \\const Fixed = @import("argument.zig").Fixed;
        );

        for (protocol.version_locked_interfaces) |interface| {
            assert(interface.version == 1);
            try interface.emit(1, protocol.namespace, writer);
        }

        for (protocol.globals) |global| {
            try global.interface.emit(global.interface.version, protocol.namespace, writer);
            for (global.children) |child| {
                try child.emit(child.version, protocol.namespace, writer);
            }
        }
    }
};

/// All data in this struct is immutable after creation in parse().
const Interface = struct {
    name: []const u8,
    version: u32,
    requests: []const Message,
    events: []const Message,
    enums: []const Enum,

    // These interfaces are special in that their version may never be increased.
    // That is, they are pinned to version 1 forever. They also may break the
    // normally required tree object creation hierarchy.
    const version_locked_interfaces = std.ComptimeStringMap(void, .{
        .{"wl_display"},
        .{"wl_registry"},
        .{"wl_callback"},
        .{"wl_buffer"},
    });
    fn version_locked(interface_name: []const u8) bool {
        return version_locked_interfaces.has(interface_name);
    }

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Interface {
        var name: ?[]const u8 = null;
        var version: ?u32 = null;
        var requests = std.ArrayList(Message).init(gpa);
        defer requests.deinit();
        var events = std.ArrayList(Message).init(gpa);
        defer events.deinit();
        var enums = std.ArrayList(Enum).init(gpa);
        defer enums.deinit();

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "request"))
                    try requests.append(try Message.parse(arena, parser))
                else if (mem.eql(u8, tag, "event"))
                    try events.append(try Message.parse(arena, parser))
                else if (mem.eql(u8, tag, "enum"))
                    try enums.append(try Enum.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "version")) {
                    if (version != null) return error.DuplicateVersion;
                    version = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "interface")) {
                return Interface{
                    .name = name orelse return error.MissingName,
                    .version = version orelse return error.MissingVersion,
                    .requests = try arena.dupe(Message, requests.items),
                    .events = try arena.dupe(Message, events.items),
                    .enums = try arena.dupe(Enum, enums.items),
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(interface: Interface, target_version: u32, namespace: []const u8, writer: anytype) !void {
        _ = namespace;
        try writer.print(
            \\pub const {[type]} = struct {{
            \\ proxy: Proxy,
            \\ pub const generated_version = {[version]};
        , .{
            .type = titleCaseTrim(interface.name),
            .version = @min(interface.version, target_version),
        });

        for (interface.enums) |e| {
            if (e.since <= target_version) {
                try e.emit(target_version, writer);
            }
        }

        const has_event = for (interface.events) |event| {
            if (event.since <= target_version) break true;
        } else false;

        if (has_event) {
            try writer.writeAll("pub const Event = union(enum) {");
            for (interface.events) |event| {
                try event.emitField(writer);
            }
            try writer.writeAll("};\n");

            try writer.writeAll(" pub const event_signatures = Proxy.genEventArgs(Event);\n");

            try writer.print(
                \\pub inline fn setListener(
                \\    self: *{[type]},
                \\    comptime T: type,
                \\    comptime _listener: fn ({[interface]}: *{[type]}, event: Event, data: T) void,
                \\    _data: T,
                \\) void {{
                \\    self.proxy.setListener({[type]}, _listener, @ptrCast(_data), );
                \\}}
            , .{
                .interface = fmtId(trimPrefix(interface.name)),
                .type = titleCaseTrim(interface.name),
            });

            var has_destroy = false;
            for (interface.requests, 0..) |request, opcode| {
                if (mem.eql(u8, request.name, "destroy")) has_destroy = true;
                try request.emitFn(writer, interface, opcode);
            }

            if (!has_destroy) {
                try writer.print(
                    \\pub fn destroy(self: *{[type]}) void {{
                    \\    self.proxy.destroy();
                    \\}}
                , .{
                    .type = titleCaseTrim(interface.name),
                });
            }
        }

        try writer.writeAll("};\n");
    }
};

/// All data in this struct is immutable after creation in parse().
const Message = struct {
    name: []const u8,
    since: u32,
    args: []const Arg,
    kind: union(enum) {
        normal: void,
        constructor: ?[]const u8,
        destructor: void,
    },

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Message {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var args = std.ArrayList(Arg).init(gpa);
        defer args.deinit();
        var destructor = false;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "arg"))
                    try args.append(try Arg.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                } else if (mem.eql(u8, attr.name, "type")) {
                    if (attr.valueEql("destructor")) {
                        destructor = true;
                    } else {
                        return error.InvalidType;
                    }
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "request") or mem.eql(u8, tag, "event")) {
                return Message{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .args = try arena.dupe(Arg, args.items),
                    .kind = blk: {
                        if (destructor) break :blk .destructor;
                        for (args.items) |arg|
                            if (arg.kind == .new_id) break :blk .{ .constructor = arg.kind.new_id };
                        break :blk .normal;
                    },
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emitField(message: Message, writer: anytype) !void {
        try writer.print("{s}", .{fmtId(message.name)});
        if (message.args.len == 0) {
            try writer.writeAll(": void,");
            return;
        }
        try writer.writeAll(": struct {");
        for (message.args) |arg| {
            if (arg.kind == .new_id) {
                try writer.print("{}: *", .{fmtId(arg.name)});
                try printAbsolute(writer, arg.kind.new_id.?);
                std.debug.assert(!arg.allow_null);
            } else {
                try writer.print("{}:", .{fmtId(arg.name)});
                // See notes on NULL in doc comment for wl_message in wayland-util.h
                if (arg.kind == .object and !arg.allow_null)
                    try writer.writeByte('?');
                try arg.emitType(writer);
            }
            try writer.writeByte(',');
        }
        try writer.writeAll("},\n");
    }

    fn emitFn(message: Message, writer: anytype, interface: Interface, opcode: usize) !void {
        try writer.writeAll("pub fn ");
        try writer.print("{}", .{camelCase(message.name)});
        try writer.print("(self: *{}", .{
            titleCaseTrim(interface.name),
        });
        for (message.args) |arg| {
            if (arg.kind == .new_id) {
                if (arg.kind.new_id == null) try writer.writeAll(", comptime T: type, _version: u32");
            } else {
                try writer.print(", _{s}:", .{arg.name});
                try arg.emitType(writer);
            }
        }

        switch (message.kind) {
            .constructor => |c| {
                if (c) |new_iface| {
                    try writer.writeAll(") !*");
                    try printAbsolute(writer, new_iface);
                    try writer.writeByte('{');
                } else {
                    try writer.writeAll(") !*T {");
                }
            },
            else => {
                try writer.writeAll(") void {");
            },
        }
        // wl_registry.bind for example needs special handling
        if (message.args.len > 0) {
            try writer.writeAll("var _args = [_]Argument{");
            for (message.args) |arg| {
                switch (arg.kind) {
                    .int, .uint, .fixed, .string, .array, .fd => {
                        try writer.writeAll(".{ .");
                        try arg.emitSignature(writer);
                        try writer.writeAll(" = ");
                        try writer.print("_{s}", .{arg.name});
                        try writer.writeAll("},");
                    },
                    .new_id => |_| {
                        try writer.writeAll(".{ .new_id = 0 },");
                    },
                    .object => {
                        try writer.writeAll(".{ .o = @ptrCast(_");
                        try writer.print("{s}) }},", .{arg.name});
                    },
                }
            }
            try writer.writeAll("};\n");
        }
        const args = if (message.args.len > 0) "&_args" else "null";
        switch (message.kind) {
            .normal => {
                try writer.print("self.proxy.marshal({}, {s});", .{ opcode, args });
            },
            .destructor => {
                try writer.print("self.proxy.marshal({}, {s});\n ", .{ opcode, args });
                try writer.writeAll("// self.proxy.destroy();\n");
            },
            .constructor => |new_iface| {
                // return @as(*Callback, @ptrCast(try _proxy.marshalConstructor(0, &_args, Callback.getInterface())));
                if (new_iface) |i| {
                    try writer.writeAll("return self.proxy.marshal_request_constructor(");
                    try printAbsolute(writer, i);
                    try writer.print(", {}, &_args);", .{opcode});
                } else {
                    try writer.print(
                        \\ _ = _version;
                        \\return self.proxy.marshal_request_constructor(T, {[opcode]}, &_args);
                    , .{
                        .opcode = opcode,
                    });
                }
            },
        }
        try writer.writeAll("}\n");
    }
};

/// All data in this struct is immutable after creation in parse().
const Arg = struct {
    const Type = union(enum) {
        int,
        uint,
        fixed,
        string,
        new_id: ?[]const u8,
        object: ?[]const u8,
        array,
        fd,
    };
    name: []const u8,
    kind: Type,
    allow_null: bool,
    enum_name: ?[]const u8,

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Arg {
        var name: ?[]const u8 = null;
        var kind: ?std.meta.Tag(Type) = null;
        var interface: ?[]const u8 = null;
        var allow_null: ?bool = null;
        var enum_name: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "type")) {
                    if (kind != null) return error.DuplicateType;
                    kind = std.meta.stringToEnum(std.meta.Tag(Type), try attr.dupeValue(arena)) orelse
                        return error.InvalidType;
                } else if (mem.eql(u8, attr.name, "interface")) {
                    if (interface != null) return error.DuplicateInterface;
                    interface = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "allow-null")) {
                    if (allow_null != null) return error.DuplicateAllowNull;
                    if (!attr.valueEql("true") and !attr.valueEql("false")) return error.InvalidBoolValue;
                    allow_null = attr.valueEql("true");
                } else if (mem.eql(u8, attr.name, "enum")) {
                    if (enum_name != null) return error.DuplicateEnum;
                    enum_name = try attr.dupeValue(arena);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "arg")) {
                return Arg{
                    .name = name orelse return error.MissingName,
                    .kind = switch (kind orelse return error.MissingType) {
                        .object => .{ .object = interface },
                        .new_id => .{ .new_id = interface },
                        .int => .int,
                        .uint => .uint,
                        .fixed => .fixed,
                        .string => .string,
                        .array => .array,
                        .fd => .fd,
                    },
                    .allow_null = allow_null orelse false,
                    .enum_name = enum_name,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emitSignature(arg: Arg, writer: anytype) !void {
        try writer.writeAll(@tagName(arg.kind));
        // switch (arg.kind) {
        //     .int => try writer.writeByte('i'),
        //     .uint => try writer.writeByte('u'),
        //     .fixed => try writer.writeByte('f'),
        //     .string => try writer.writeByte('s'),
        //     .new_id => |interface| if (interface == null)
        //         try writer.writeAll("sun")
        //     else
        //         try writer.writeAll("new_id"),
        //     .object => try writer.writeAll('object'),
        //     .array => try writer.writeByte('a'),
        //     .fd => try writer.writeByte('h'),
        // }
    }

    fn emitType(arg: Arg, writer: anytype) !void {
        switch (arg.kind) {
            .int, .uint => {
                if (arg.enum_name) |name| {
                    if (mem.indexOfScalar(u8, name, '.')) |dot_index| {
                        // Turn a reference like wl_shm.format into common.wl.shm.Format
                        const us_index = mem.indexOfScalar(u8, name, '_') orelse 0;
                        try writer.print("{s}{}", .{
                            titleCase(name[us_index + 1 .. dot_index + 1]),
                            titleCase(name[dot_index + 1 ..]),
                        });
                        // try writer.print("{s}.{s}{}", .{
                        //     name[0..us_index],
                        //     name[us_index + 1 .. dot_index + 1],
                        //     titleCase(name[dot_index + 1 ..]),
                        // });
                    } else {
                        try writer.print("{}", .{titleCase(name)});
                    }
                } else if (arg.kind == .int) {
                    try writer.writeAll("i32");
                } else {
                    try writer.writeAll("u32");
                }
            },
            .new_id => try writer.writeAll("u32"),
            .fixed => try writer.writeAll("Fixed"),
            .string => {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("[*:0]const u8");
            },
            .object => |interface| if (interface) |i| {
                if (arg.allow_null) try writer.writeAll("?*") else try writer.writeByte('*');
                try printAbsolute(writer, i);
            } else {
                if (arg.allow_null) try writer.writeByte('?');
                try writer.writeAll("*anyopaque");
            },
            .array => {
                if (arg.allow_null) try writer.writeByte('?');
                // try writer.writeAll("*Array");
                try writer.writeAll("*anyopaque");
            },
            .fd => try writer.writeAll("i32"),
        }
    }
};

/// All data in this struct is immutable after creation in parse().
const Enum = struct {
    name: []const u8,
    since: u32,
    entries: []const Entry,
    bitfield: bool,

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Enum {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var entries = std.ArrayList(Entry).init(gpa);
        defer entries.deinit();
        var bitfield: ?bool = null;

        while (parser.next()) |ev| switch (ev) {
            .open_tag => |tag| {
                // TODO: parse description
                if (mem.eql(u8, tag, "entry"))
                    try entries.append(try Entry.parse(arena, parser));
            },
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                } else if (mem.eql(u8, attr.name, "bitfield")) {
                    if (bitfield != null) return error.DuplicateBitfield;
                    if (!attr.valueEql("true") and !attr.valueEql("false")) return error.InvalidBoolValue;
                    bitfield = attr.valueEql("true");
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "enum")) {
                return Enum{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .entries = try arena.dupe(Entry, entries.items),
                    .bitfield = bitfield orelse false,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    fn emit(e: Enum, target_version: u32, writer: anytype) !void {
        try writer.print("pub const {}", .{titleCase(e.name)});

        if (e.bitfield) {
            var entries_emitted: u8 = 0;
            try writer.writeAll(" = packed struct(u32) {");
            for (e.entries) |entry| {
                if (entry.since <= target_version) {
                    const value = entry.intValue();
                    if (value != 0 and std.math.isPowerOfTwo(value)) {
                        try writer.print("{s}: bool = false,", .{entry.name});
                        entries_emitted += 1;
                    }
                }
            }
            if (entries_emitted < 32) {
                try writer.print("_padding: u{d} = 0,\n", .{32 - entries_emitted});
            }

            // Emit the normal C abi enum as well as it may be needed to interface
            // with C code.
            try writer.writeAll("pub const Enum ");
        }

        try writer.writeAll(" = enum(c_int) {");
        for (e.entries) |entry| {
            if (entry.since <= target_version) {
                try writer.print("{s}= {s},", .{ fmtId(entry.name), entry.value });
            }
        }
        // Always generate non-exhaustive enums to ensure forward compatability.
        // Entries have been added to wl_shm.format without bumping the version.
        try writer.writeAll("_,};\n");

        if (e.bitfield) try writer.writeAll("};\n");
    }
};

/// All data in this struct is immutable after creation in parse().
const Entry = struct {
    name: []const u8,
    since: u32,
    value: []const u8,

    fn parse(arena: mem.Allocator, parser: *xml.Parser) !Entry {
        var name: ?[]const u8 = null;
        var since: ?u32 = null;
        var value: ?[]const u8 = null;

        while (parser.next()) |ev| switch (ev) {
            .attribute => |attr| {
                if (mem.eql(u8, attr.name, "name")) {
                    if (name != null) return error.DuplicateName;
                    name = try attr.dupeValue(arena);
                } else if (mem.eql(u8, attr.name, "since")) {
                    if (since != null) return error.DuplicateSince;
                    since = try std.fmt.parseInt(u32, try attr.dupeValue(arena), 10);
                } else if (mem.eql(u8, attr.name, "value")) {
                    if (value != null) return error.DuplicateName;
                    value = try attr.dupeValue(arena);
                }
            },
            .close_tag => |tag| if (mem.eql(u8, tag, "entry")) {
                return Entry{
                    .name = name orelse return error.MissingName,
                    .since = since orelse 1,
                    .value = value orelse return error.MissingValue,
                };
            },
            else => {},
        };
        return error.UnexpectedEndOfFile;
    }

    // Return numeric value of enum entry. Can be base 10 and hexadecimal notation.
    fn intValue(e: Entry) u32 {
        return std.fmt.parseInt(u32, e.value, 10) catch blk: {
            const index = mem.indexOfScalar(u8, e.value, 'x').?;
            break :blk std.fmt.parseInt(u32, e.value[index + 1 ..], 16) catch @panic("Can't parse enum entry.");
        };
    }
};

fn prefix(s: []const u8) ?[]const u8 {
    return s[0 .. mem.indexOfScalar(u8, s, '_') orelse return null];
}

fn trimPrefix(s: []const u8) []const u8 {
    return s[mem.indexOfScalar(u8, s, '_').? + 1 ..];
}

const Case = enum { title, camel };

fn formatCaseImpl(comptime case: Case, comptime trim: bool) type {
    return struct {
        pub fn f(
            bytes: []const u8,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            var upper = case == .title;
            const str = if (trim) trimPrefix(bytes) else bytes;
            for (str) |c| {
                if (c == '_') {
                    upper = true;
                    continue;
                }
                try writer.writeByte(if (upper) std.ascii.toUpper(c) else c);
                upper = false;
            }
        }
    };
}

fn titleCase(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.title, false).f) {
    return .{ .data = bytes };
}

fn titleCaseTrim(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.title, true).f) {
    return .{ .data = bytes };
}

fn camelCase(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.camel, false).f) {
    return .{ .data = bytes };
}

fn camelCaseTrim(bytes: []const u8) std.fmt.Formatter(formatCaseImpl(.camel, true).f) {
    return .{ .data = bytes };
}

fn printAbsolute(writer: anytype, interface: []const u8) !void {
    // try writer.print("{s}.{}", .{
    //     prefix(interface) orelse return error.MissingPrefix,
    //     titleCaseTrim(interface),
    // });
    try writer.print("{}", .{
        titleCaseTrim(interface),
    });
}

test "parsing" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const xml_protocol_content = try std.fs.cwd().readFileAlloc(arena.allocator(), "/usr/share/wayland/wayland.xml", std.math.maxInt(usize));

    const protocol = try Protocol.parseXML(arena.allocator(), xml_protocol_content);

    try testing.expectEqualSlices(u8, "wayland", protocol.name);
    try testing.expectEqual(@as(usize, 7), protocol.globals.len);

    {
        const wl_display = protocol.version_locked_interfaces[0];
        try testing.expectEqualSlices(u8, "wl_display", wl_display.name);
        try testing.expectEqual(@as(u32, 1), wl_display.version);
        try testing.expectEqual(@as(usize, 2), wl_display.requests.len);
        try testing.expectEqual(@as(usize, 2), wl_display.events.len);
        try testing.expectEqual(@as(usize, 1), wl_display.enums.len);

        {
            const sync = wl_display.requests[0];
            try testing.expectEqualSlices(u8, "sync", sync.name);
            try testing.expectEqual(@as(u32, 1), sync.since);
            try testing.expectEqual(@as(usize, 1), sync.args.len);
            {
                const callback = sync.args[0];
                try testing.expectEqualSlices(u8, "callback", callback.name);
                try testing.expect(callback.kind == .new_id);
                try testing.expectEqualSlices(u8, "wl_callback", callback.kind.new_id.?);
                try testing.expectEqual(false, callback.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), callback.enum_name);
            }
            try testing.expect(sync.kind == .constructor);
        }

        {
            const error_event = wl_display.events[0];
            try testing.expectEqualSlices(u8, "error", error_event.name);
            try testing.expectEqual(@as(u32, 1), error_event.since);
            try testing.expectEqual(@as(usize, 3), error_event.args.len);
            {
                const object_id = error_event.args[0];
                try testing.expectEqualSlices(u8, "object_id", object_id.name);
                try testing.expectEqual(Arg.Type{ .object = null }, object_id.kind);
                try testing.expectEqual(false, object_id.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), object_id.enum_name);
            }
            {
                const code = error_event.args[1];
                try testing.expectEqualSlices(u8, "code", code.name);
                try testing.expectEqual(Arg.Type.uint, code.kind);
                try testing.expectEqual(false, code.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), code.enum_name);
            }
            {
                const message = error_event.args[2];
                try testing.expectEqualSlices(u8, "message", message.name);
                try testing.expectEqual(Arg.Type.string, message.kind);
                try testing.expectEqual(false, message.allow_null);
                try testing.expectEqual(@as(?[]const u8, null), message.enum_name);
            }
        }

        {
            const error_enum = wl_display.enums[0];
            try testing.expectEqualSlices(u8, "error", error_enum.name);
            try testing.expectEqual(@as(u32, 1), error_enum.since);
            try testing.expectEqual(@as(usize, 4), error_enum.entries.len);
            {
                const invalid_object = error_enum.entries[0];
                try testing.expectEqualSlices(u8, "invalid_object", invalid_object.name);
                try testing.expectEqual(@as(u32, 1), invalid_object.since);
                try testing.expectEqualSlices(u8, "0", invalid_object.value);
            }
            {
                const invalid_method = error_enum.entries[1];
                try testing.expectEqualSlices(u8, "invalid_method", invalid_method.name);
                try testing.expectEqual(@as(u32, 1), invalid_method.since);
                try testing.expectEqualSlices(u8, "1", invalid_method.value);
            }
            {
                const no_memory = error_enum.entries[2];
                try testing.expectEqualSlices(u8, "no_memory", no_memory.name);
                try testing.expectEqual(@as(u32, 1), no_memory.since);
                try testing.expectEqualSlices(u8, "2", no_memory.value);
            }
            {
                const implementation = error_enum.entries[3];
                try testing.expectEqualSlices(u8, "implementation", implementation.name);
                try testing.expectEqual(@as(u32, 1), implementation.since);
                try testing.expectEqualSlices(u8, "3", implementation.value);
            }
            try testing.expectEqual(false, error_enum.bitfield);
        }
    }

    {
        const wl_data_offer = protocol.globals[2].children[2];
        try testing.expectEqualSlices(u8, "wl_data_offer", wl_data_offer.name);
        try testing.expectEqual(@as(u32, 3), wl_data_offer.version);
        try testing.expectEqual(@as(usize, 5), wl_data_offer.requests.len);
        try testing.expectEqual(@as(usize, 3), wl_data_offer.events.len);
        try testing.expectEqual(@as(usize, 1), wl_data_offer.enums.len);

        {
            const accept = wl_data_offer.requests[0];
            try testing.expectEqualSlices(u8, "accept", accept.name);
            try testing.expectEqual(@as(u32, 1), accept.since);
            try testing.expectEqual(@as(usize, 2), accept.args.len);
            {
                const serial = accept.args[0];
                try testing.expectEqualSlices(u8, "serial", serial.name);
                try testing.expectEqual(Arg.Type.uint, serial.kind);
                try testing.expectEqual(false, serial.allow_null);
            }
            {
                const mime_type = accept.args[1];
                try testing.expectEqualSlices(u8, "mime_type", mime_type.name);
                try testing.expectEqual(Arg.Type.string, mime_type.kind);
                try testing.expectEqual(true, mime_type.allow_null);
            }
        }
    }
}

test "generate" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    const alloc = arena.allocator();
    defer arena.deinit();

    const xml_protocol_content = try std.fs.cwd().readFileAlloc(arena.allocator(), "/usr/share/wayland/wayland.xml", std.math.maxInt(usize));

    const protocol = try Protocol.parseXML(arena.allocator(), xml_protocol_content);

    const generated_filename = try mem.concat(alloc, u8, &.{ "src/", protocol.name, "_generated.zig" });
    const generated_file = try fs.cwd().createFile(generated_filename, .{});
    defer generated_file.close();

    try protocol.emit(generated_file.writer());
}
