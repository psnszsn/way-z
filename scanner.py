# pyright: strict
# Adapted from https://github.com/sde1000/python-wayland/blob/master/wayland/protocol.py

from __future__ import annotations
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Never, TextIO
from pprint import pprint
import subprocess


def title_case(txt: str) -> str:
    return "".join(w.capitalize() for w in txt.split("_"))


# def camel_case(txt: str) -> str:
#     return "".join(w.capitalize() for w in txt.split("_"))


@dataclass(slots=True)
class Arg:
    parent: Event | Request
    type: str
    name: str
    description: str | None = field(repr=False)
    summary: str = field(repr=False)
    allow_null: bool

    interface: str | None
    enum: str | None

    def __init__(self, parent: Event | Request, arg: ET.Element):
        self.parent = parent
        self.name = arg.get("name") or Never
        self.type = arg.get("type") or Never

        self.description = None
        self.summary = arg.get("summary") or Never
        self.allow_null = arg.get("allow-null", None) == "true"

        self.interface = arg.get("interface")
        self.enum = arg.get("enum")

        for c in arg:
            if c.tag == "description":
                self.description = c.text
                self.summary = c.get("summary") or Never

    def zig_type(self, obj_use_ptr:bool = False) -> str:
        # print(self)
        protocol = self.parent.interface.protocol
        match self.type:
            case "int" | "uint":
                if e := self.enum:
                    # eg: wl_data_device_manager.dnd_action
                    parts = e.split(".", 1)
                    if len(parts) == 1:
                        return title_case(self.parent.interface.enums[parts[0]].name)
                    if len(parts) == 2:
                        interface, enum = parts
                        interface = protocol.interfaces[interface]
                        enum = interface.enums[enum]
                        return ".".join(
                            title_case(x) for x in [interface.name, enum.name]
                        )

                    # print(parts)
                else:
                    return "i32" if self.type == "int" else "u32"

            case "new_id":
                return "u32"
            case "fixed":
                return "Fixed"
            case "string":
                return "?[*:0]const u8" if self.allow_null else "[*:0]const u8"
            case "object":
                if not obj_use_ptr: return "u32"
                qs = "?*" if self.allow_null else "*"
                if not self.interface:
                    return qs + "anyopaque"
                interface = protocol.find_interface(self.interface)
                prefix = interface.prefix + "." if interface.prefix != protocol.prefix else ""
                return qs + prefix + title_case(interface.name)
            case "array":
                return "*anyopaque"
            case "fd":
                return "i32"
            case _:
                assert False, self.type

        return Never


@dataclass(slots=True)
class Request:
    """A request on an interface.

    Requests have a name, optional type (to indicate whether the
    request destroys the object), optional "since version of
    interface", optional description, and optional summary.

    If a request has an argument of type "new_id" then the request
    creates a new object; the Interface for this new object is
    accessible as the "creates" attribute.
    """

    interface: Interface
    opcode: int
    name: str
    type: str
    since: int
    args: list[Arg]

    description: str | None = field(repr=False)
    summary: str | None = field(repr=False)

    def __init__(self, interface: Interface, opcode: int, request: ET.Element):
        self.interface = interface
        self.opcode = opcode
        assert request.tag == "request"

        self.name = request.get("name") or Never
        self.type = request.get("type", "normal")
        self.since = int(request.get("since", 1))

        self.description = None
        self.summary = None

        self.args = []

        for c in request:
            match c.tag:
                case "description":
                    self.description = c.text
                    self.summary = c.get("summary") or Never
                case "arg":
                    a = Arg(self, c)
                    # if a.type == "new_id":
                    #     self.creates = a.interface
                    self.args.append(a)
                case _:
                    pass

    def __str__(self):
        return "{}.{}".format(self.interface.name, self.name)

    def emit_fn(self, fd: TextIO):
        # return
        fd.write(f"pub fn {self.name}(self: *const {self.interface.zig_type()}")

        for arg in self.args:
            if arg.type == "new_id":
                self.type = "constructor"
                if not arg.interface:
                    fd.write(f", comptime T: type, _version: u32")
            else:
                fd.write(f", _{arg.name}: {arg.zig_type(obj_use_ptr=True)}")

        fd.write(")")

        interface = None
        match self.type:
            case "constructor":
                creates_interface = next(
                    (
                        arg.interface
                        for arg in self.args
                        if arg.type == "new_id" and arg.interface
                    ),
                    None,
                )
                if creates_interface:
                    interface = self.interface.protocol.interfaces[creates_interface]
                    fd.write(f"!*{title_case(interface.name)}")
                else:
                    fd.write("!*T")
            case _:
                fd.write("void")
        fd.write("{\n")

        if self.args:
            fd.write("var _args = [_]Argument{")
            for arg in self.args:
                match arg.type:
                    case "new_id":
                        if not interface:
                            fd.write(".{ .string = T.interface.name },")
                            fd.write(".{ .uint = _version },")
                        fd.write(".{ .new_id = 0 },")

                    case "object" if arg.allow_null:
                        fd.write(f".{{ .object = if(_{arg.name})|arg| arg.proxy.id else 0 }},")
                    case "object":
                        fd.write(f".{{ .object = _{arg.name}.proxy.id }},")
                    case "uint" if arg.enum:
                        fd.write(f".{{ .uint = @intCast(@intFromEnum(_{arg.name})) }},")
                    case other:
                        fd.write(f".{{ .{other} = _{arg.name} }},")
            fd.write("};\n")

        args_ref = "&_args" if self.args else "&.{}"
        match self.type:
            case "normal":
                fd.write(f"self.proxy.marshal_request({self.opcode}, {args_ref}) catch unreachable;\n")
            case "destructor":
                fd.write(f"self.proxy.marshal_request({self.opcode}, {args_ref}) catch unreachable;\n")
                fd.write("// self.proxy.destroy();\n")
            case "constructor":
                ret_t = interface.zig_type() if interface else "T"
                fd.write(
                    f"return self.proxy.marshal_request_constructor({ret_t}, {self.opcode}, &_args);\n"
                )
            case _:
                assert False, self

        fd.write("}\n")


@dataclass(slots=True)
class EnumEntry:
    name: str
    value: int
    since: int
    description: str | None = field(repr=False)
    summary: str | None = field(repr=False)

    def __init__(self, entry: ET.Element):
        assert entry.tag == "entry"

        self.name = entry.get("name") or Never
        value = entry.get("value") or Never
        self.value = int(value, base=0)
        self.description = None
        self.summary = entry.get("summary", None)
        self.since = int(entry.get("since", 1))

        for c in entry:
            if c.tag == "description":
                self.description = c.text
                self.summary = c.get("summary")


@dataclass(slots=True)
class Enum:
    """An enumeration declared in an interface.

    Enumerations have a name, optional "since version of interface",
    option description, optional summary, and a number of entries.

    The entries are accessible by name in the dictionary available
    through the "entries" attribute.  Further, if the Enum instance is
    accessed as a dictionary then if a string argument is used it
    returns the integer value of the corresponding entry, and if an
    integer argument is used it returns the name of the corresponding
    entry.
    """

    name: str
    since: int
    entries: dict[str, EnumEntry]
    bitfield: bool

    description: str | None = field(repr=False)
    summary: str | None = field(repr=False)

    def __init__(self, enum: ET.Element):
        assert enum.tag == "enum"

        self.name = enum.get("name") or Never
        # print(self.name)
        self.since = int(enum.get("since", 1))
        self.entries = {}
        self.bitfield = enum.get("bitfield", None) == "true"
        self.description = None
        self.summary = None

        for c in enum:
            if c.tag == "description":
                self.description = c.text
                self.summary = c.get("summary")
            elif c.tag == "entry":
                e = EnumEntry(c)
                self.entries[e.name] = e

    def emit(self, fd: TextIO):
        fd.write(f"pub const {title_case(self.name)}")

        if self.bitfield:
            fd.write(" = packed struct(u32) {")
            total_entries = 0
            for entry in self.entries.values():
                if entry.value == 0:
                    continue
                if entry.value & (entry.value - 1) != 0:
                    continue
                fd.write(f"{entry.name}: bool = false,")
                total_entries += 1

            if total_entries < 32:
                fd.write(f"_padding: u{32-total_entries} = 0,\n")
        else:
            fd.write("= enum(c_int){")
            for entry in self.entries.values():
                fd.write(f'@"{entry.name}"= {entry.value},')
        fd.write("};\n")


@dataclass(slots=True)
class Event:
    """An event on an interface.

    Events have a number (which depends on the order in which they are
    declared in the protocol XML file), name, optional "since version
    of interface", optional description, optional summary, and a
    number of arguments.
    """

    interface: Interface = field(repr=False)
    name: str
    number: int
    since: int
    args: list[Arg]
    description: str | None = field(repr=False)
    summary: str | None = field(repr=False)

    def __init__(self, interface: Interface, event: ET.Element, number: int):
        self.interface = interface
        assert event.tag == "event"

        self.name = event.get("name") or Never
        self.number = number
        self.since = int(event.get("since", 1))
        self.args = []
        self.description = None
        self.summary = None

        for c in event:
            match c.tag:
                case "description":
                    self.description = c.text
                    self.summary = c.get("summary")
                case "arg":
                    self.args.append(Arg(self, c))
                case _:
                    return Never

    def __str__(self):
        return "{}::{}".format(self.interface, self.name)

    def emit_field(self, fd: TextIO):
        fd.write(f'''@"{self.name}"''')
        if not self.args:
            fd.write(": void,")
            return

        fd.write(": struct{")
        for arg in self.args:
            if arg.type == "new_id":
                assert arg.interface
                interface = self.interface.protocol.interfaces[arg.interface].zig_type()
                fd.write(f"{arg.name}: *{interface}")
                assert not arg.allow_null
            else:
                fd.write(f"{arg.name}: ")
                if arg.type == "object" and not arg.allow_null:
                    fd.write("?")
                fd.write(arg.zig_type())
                fd.write(", ")
        fd.write("},\n")


@dataclass(slots=True)
class Interface:
    """A Wayland protocol interface.

    Wayland interfaces have a name and version, plus a number of
    requests, events and enumerations.  Optionally they have a
    description.

    The name and version are accessible as the "name" and "version"
    attributes.

    The requests and enums are accessible as dictionaries as the
    "requests" and "enums" attributes.  The events are accessible by
    name as a dictionary as the "events_by_name" attribute, and by
    number as a list as the "events_by_number" attribute.

    A client proxy class for this interface is available as the
    "client_proxy_class" attribute; instances of this class have
    methods corresponding to the requests, and deal with dispatching
    the events.
    """

    protocol: Protocol
    version: int
    prefix: str
    name: str
    description: str | None = field(repr=False)
    summary: str | None = field(repr=False)
    requests: dict[str, Request]
    events: dict[str, Event]
    enums: dict[str, Enum]

    def __init__(self, protocol: Protocol, interface: ET.Element):
        self.protocol = protocol
        assert interface.tag == "interface"

        full_name = interface.get("name") or Never
        self.prefix, self.name = full_name.split("_", 1)
        if v := interface.get("version"):
            self.version = int(v)
        assert self.version > 0
        self.description = None
        self.summary = None
        self.requests = {}
        self.events = {}
        self.enums = {}

        for c in interface:
            match c.tag:
                case "description":
                    self.description = c.text
                    self.summary = c.get("summary")
                case "request":
                    e = Request(self, len(self.requests), c)
                    self.requests[e.name] = e
                    pass
                case "event":
                    e = Event(self, c, len(self.events) + 1)
                    self.events[e.name] = e
                case "enum":
                    e = Enum(c)
                    self.enums[e.name] = e
                case _:
                    assert False, "unreachable"

    def __str__(self):
        return self.name

    def __repr__(self):
        return "Interface('{}', {})".format(self.name, self.version)

    def zig_type(self) -> str:
        return title_case(self.name)

    def emit(self, fd: TextIO):
        name_camel = "".join(w.capitalize() for w in self.name.split("_"))
        fd.write(
            f"""pub const {name_camel} = struct {{
            proxy: Proxy,
            pub const interface = Interface{{
               .name = "{self.prefix}_{self.name}",
               .version = {self.version},
            """
        )
        if self.events:
            fd.write(".event_signatures = &Proxy.genEventArgs(Event),\n")
            event_names = "".join(f'"{event.name}",' for event in self.events.values())
            fd.write(f".event_names = &.{{{event_names}}},\n")

        if self.requests:
            request_names = "".join(f'"{req.name}",' for req in self.requests.values())
            fd.write(f".request_names = &.{{{request_names}}},\n")

        fd.write("};")

        for enum in self.enums.values():
            enum.emit(fd)

        if self.events:
            fd.write("pub const Event = union(enum) {")
            for e in self.events.values():
                e.emit_field(fd)
            fd.write("};\n")

            fd.write(f"""
                pub inline fn set_listener(
                    self: *{name_camel},
                    comptime T: type,
                    comptime _listener: *const fn (*{name_camel}, Event, T) void,
                    _data: T,
                ) void {{
                    const w = struct{{
                        fn inner(impl: *anyopaque, opcode: u16, args: []Argument, __data: ?*anyopaque) void {{
                            const event = switch (opcode) {{
                        """)
            for i, e in enumerate(self.events.values()):
                fd.write(f"{i} => Event")
                if e.args:
                    fd.write("{")
                fd.write(f'''.@"{e.name}"''')

                if not e.args:
                    fd.write(",")
                    continue

                fd.write("= .{")
                for arg_i, arg in enumerate(e.args):
                    fd.write(f'''.@"{arg.name}" = ''')
                    match arg.type:
                        case "array":
                            fd.write("undefined,")
                        case "uint" if arg.enum:
                            fd.write(f"@bitCast(args[{arg_i}].uint),")
                        case t:
                            fd.write(f"args[{arg_i}].{t},")

                fd.write("}")
                fd.write("},")
            fd.write("else => unreachable,")

            fd.write("};")
            if (all(not e.args for e in self.events.values() )):
                fd.write("_ = args;")
            fd.write(f"""
                        @call(.always_inline, _listener, .{{
                            @as(*{name_camel}, @ptrCast(@alignCast(impl))),
                            event,
                            @as(T, @ptrCast(@alignCast(__data))),
                        }});
                    }}
                }};

                self.proxy.listener = w.inner;
                self.proxy.listener_data = _data;

            }}
            """)

        for e in self.requests.values():
            e.emit_fn(fd)

        fd.write("};\n")


@dataclass(slots=True)
class Protocol:
    copyright: str = field(repr=False)
    name: str
    interfaces: dict[str, Interface]
    prefix : str
    parent: Protocol | None = field(repr=False)

    def __init__(self, file: Path, parent: Protocol | None = None):
        tree = ET.parse(file)

        protocol = tree.getroot()
        assert protocol.tag == "protocol"

        self.interfaces = parent.interfaces if parent else {}
        self.name = protocol.get("name") or Never
        self.parent = None

        for c in protocol:
            if c.tag == "copyright":
                assert c.text
                self.copyright = c.text

            elif c.tag == "interface":
                i = Interface(self, c)
                if i.name in self.interfaces:
                    raise ValueError(f"Duplicate interface: {i.name}")
                self.interfaces[c.get("name") or Never] = i

        self.prefix = next(iter(self.interfaces.values())).prefix
        assert all(proto.prefix == self.prefix for proto in self.interfaces.values())

    def find_interface(self, name: str) -> Interface:
        if interface := self.interfaces.get(name):
            return interface
        global protocols
        prefix = name.split("_")[0]
        parent_protocol = protocols[prefix]
        if self.parent is not None:
            assert self.parent is parent_protocol
        else:
            self.parent = parent_protocol
        interface = parent_protocol.interfaces[name]
        return interface

    def emit(self, fd: TextIO):
        fd.write(
            """\
            const std = @import("std");
            const os = std.os;
            const Proxy = @import("../proxy.zig").Proxy;
            const Interface = @import("../proxy.zig").Interface;
            const Argument = @import("../argument.zig").Argument;
            const Fixed = @import("../argument.zig").Fixed;

            """
        )
        if self.parent:
            fd.write(f"""
            const {self.parent.prefix} = @import("{self.parent.prefix}.zig");
            """)

        for i in self.interfaces.values():
            i.emit(fd)


protocols: dict[str, Protocol] = {}


def main():
    global protocols
    xml_protocols = [
        "/usr/share/wayland/wayland.xml",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
        # "/usr/share/wayland-protocols/stable/presentation-time/presentation-time.xml",
        # "/usr/share/wayland-protocols/stable/viewporter/viewporter.xml",
    ]
    for p in xml_protocols:
        p = Protocol(Path(p))
        protocols[p.prefix] = p
        out = Path(__file__).parent / f"src/generated/{p.prefix}.zig"
        out.parent.mkdir(exist_ok=True)
        with out.open("w") as f:
            p.emit(f)
        with out.open("w") as f:
            p.emit(f)
        pprint(p)

        subprocess.run(["zig", "fmt", str(out)], check=True)


if __name__ == "__main__":
    main()
