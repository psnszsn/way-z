#!/usr/bin/env python
# pyright: strict
# TODO: Use ZigEtc everywhere

from __future__ import annotations
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar, NamedTuple, Never, TextIO
from pprint import pprint
import subprocess
import io


@dataclass(slots=True)
class Zig:
    def zig_it(self) -> str:
        raise NotImplemented()


@dataclass(slots=True)
class ZigAssignment(Zig):
    name: str
    value: Zig

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("pub const ")
        out.write(self.name)
        out.write("= ")
        out.write(self.value.zig_it())
        out.write(";\n")
        return out.getvalue()


@dataclass(slots=True)
class ZigUnion(Zig):
    class Varinat(NamedTuple):
        name: str
        payload: Zig | None
        doc_comment: str | None = None

    variants: list[Varinat]
    extra: list[Zig] = field(default_factory=list)

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("union(enum) {")
        for variant in self.variants:
            emit_comment(variant.doc_comment, out)
            out.write(f'''@"{variant.name}"''')
            out.write(": ")
            if variant.payload:
                out.write(variant.payload.zig_it())
            else:
                out.write("void")
            out.write(",")
        for decl in self.extra:
            out.write("\n")
            out.write(decl.zig_it())
        out.write("}")
        return out.getvalue()


@dataclass(slots=True)
class ZigStruct(Zig):
    class Field(NamedTuple):
        name: str
        typ: str
        comment: str | None = None
        default_value: str | None = None

    fields: list[Field]

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("struct {")
        for field in self.fields:
            out.write(f'''@"{field.name}"''')
            out.write(": ")
            out.write(field.typ)
            if field.default_value:
                out.write(" = ")
                out.write(field.default_value)
            out.write(",")
            if field.comment:
                out.write(" // ")
                out.write(field.comment)
                out.write("\n")
        out.write("}")
        return out.getvalue()


@dataclass(slots=True)
class ZigStructInit(Zig):
    class Field(NamedTuple):
        name: str
        value: str

    struct_type: str | None
    fields: list[Field]

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write(self.struct_type or ".")
        out.write("{")
        for field in self.fields:
            out.write(f'''.@"{field.name}"''')
            out.write("= ")
            out.write(field.value)
            out.write(",")
        out.write("}")
        return out.getvalue()


@dataclass(slots=True)
class ZigFn(Zig):
    name: str
    args: list[tuple[str, str]]
    return_type: str
    body: Zig

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("\n")
        out.write("pub fn ")
        out.write(self.name)
        out.write("(")
        for arg in self.args:
            out.write(arg[0])
            out.write(": ")
            out.write(arg[1])
            out.write(",")
        out.write(") ")
        out.write(self.return_type)
        out.write("{\n")
        out.write(self.body.zig_it())
        out.write("}\n\n")
        return out.getvalue()


@dataclass(slots=True)
class ZigReturn(Zig):
    body: Zig

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("return ")
        out.write(self.body.zig_it())
        out.write(";\n")
        return out.getvalue()


@dataclass(slots=True)
class ZigSwitch(Zig):
    value: str
    variants: list[tuple[str, str]]

    def zig_it(self) -> str:
        out = io.StringIO()
        out.write("switch(")
        out.write(self.value)
        out.write("){\n")
        for v in self.variants:
            out.write(v[0])
            out.write("=>")
            out.write(v[1])
            out.write(",")
        out.write("}")
        return out.getvalue()


def title_case(txt: str) -> str:
    return "".join(w.capitalize() for w in txt.split("_"))


def emit_comment(description: str | None, fd: TextIO, commment_type: str = "///"):
    if description:
        for line in description.strip().splitlines():
            fd.write(f"\n{commment_type} {line.strip()}")
        fd.write("\n")


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
        self.summary = arg.get("summary") or ""
        self.allow_null = arg.get("allow-null", None) == "true"

        self.interface = arg.get("interface")
        self.enum = arg.get("enum")

        for c in arg:
            if c.tag == "description":
                self.description = c.text
                self.summary = c.get("summary") or Never

    def zig_struct_field(self) -> ZigStruct.Field:
        if self.type == "new_id":
            if self.interface:
                interface = self.parent.interface.protocol.interfaces[
                    self.interface
                ].zig_type()
                default = "@enumFromInt(0)"
            else:
                interface = "u32"
                default = "0"
            assert not self.allow_null
            return ZigStruct.Field(
                self.name, interface, default_value=default, comment=self.summary
            )
        else:
            qm = "?" if self.type == "object" and not self.allow_null else ""
            return ZigStruct.Field(
                self.name, qm + self.zig_type(obj_use_ptr=True), comment=self.summary
            )
        # if self.summary:
        #     fd.write(f"// {self.summary}\n")

    def zig_type(self, obj_use_ptr: bool = False) -> str:
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
                return "?[:0]const u8" if self.allow_null else "[:0]const u8"
            case "object":
                if not obj_use_ptr:
                    return "u32"
                qs = "?" if self.allow_null else ""
                if not self.interface:
                    return qs + "u32"
                interface = protocol.find_interface(self.interface)
                prefix = (
                    interface.prefix + "."
                    if interface.prefix != protocol.prefix
                    else ""
                )
                return qs + prefix + title_case(interface.name)
            case "array" if self.interface:
                interface = protocol.find_interface(self.interface)
                prefix = (
                    interface.prefix + "."
                    if interface.prefix != protocol.prefix
                    else ""
                )
                return "[]" + prefix + title_case(interface.name)
            case "array":
                return "[]u8"
            case "fd":
                return "std.posix.fd_t"
            case _:
                assert False, self.type

        return Never


@dataclass(slots=True)
class Request:
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
                    self.summary = c.get("summary") or ""
                case "arg":
                    a = Arg(self, c)
                    # if a.type == "new_id":
                    #     self.creates = a.interface
                    self.args.append(a)
                case _:
                    pass

    def __str__(self):
        return "{}.{}".format(self.interface.name, self.name)

    def zig_union_variant(self) -> ZigUnion.Varinat:
        zig_struct = ZigStruct([arg.zig_struct_field() for arg in self.args])
        return ZigUnion.Varinat(
            name=self.name,
            payload=zig_struct if zig_struct.fields else None,
            doc_comment=self.description,
        )

    def zig_return_type(self) -> str:
        if any(arg.type == "new_id" for arg in self.args):
            self.type = "constructor"

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
                    return f"{title_case(interface.name)}"
                else:
                    return '@compileError("BIND")'
            case _:
                return "void"


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

    def zig_union_variant(self) -> ZigUnion.Varinat:
        zig_struct = ZigStruct(
            [arg.zig_struct_field() for arg in self.args if arg.type != "new_id"]
        )
        return ZigUnion.Varinat(
            name=self.name,
            payload=zig_struct if zig_struct.fields else None,
            doc_comment=self.description,
        )


@dataclass(slots=True)
class Interface:
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

    def find_enum(self, name: str) -> Enum:
        parts = name.split(".")
        if len(parts) == 1:
            return self.enums[name]
        if len(parts) == 2:
            interface = self.protocol.find_interface(parts[0])
            return interface.enums[parts[1]]
        assert False, "unreachable"

    def interface_impl(self) -> str:
        val = ZigStructInit(
            "Interface",
            [
                ZigStructInit.Field("name", f'"{self.prefix}_{self.name}"'),
                ZigStructInit.Field("version", str(self.version)),
            ],
        )
        if self.events:
            event_signatures = ""
            for event in self.events.values():
                arg_sign = ", ".join(f".{arg.type}" for arg in event.args)
                event_signatures += f"&.{{{arg_sign}}},"

            val.fields.append(
                ZigStructInit.Field("event_signatures", f"&.{{{event_signatures}}}")
            )
            event_names = "".join(f'"{event.name}",' for event in self.events.values())
            val.fields.append(
                ZigStructInit.Field("event_names", f"&.{{{event_names}}}")
            )

        if self.requests:
            request_names = "".join(f'"{req.name}",' for req in self.requests.values())
            val.fields.append(
                ZigStructInit.Field("request_names", f"&.{{{request_names}}}")
            )

        return ZigAssignment("interface", val).zig_it()

    def from_args_fn(self) -> ZigFn:
        def getv(e: Event) -> str:

            f_fields: list[ZigStructInit.Field] = []
            for arg_i, arg in enumerate(e.args):
                match arg.type:
                    case "array":
                        val = f"args[{arg_i}].array.slice(u8)"
                    case "uint" if arg.enum:
                        enum = self.find_enum(arg.enum)
                        if enum.bitfield:
                            val = f"@bitCast(args[{arg_i}].uint)"
                        else:
                            val = f"@enumFromInt(args[{arg_i}].uint)"
                    case "object" if arg.interface:
                        val = f"@enumFromInt(args[{arg_i}].object)"
                    case "object":
                        val = f"args[{arg_i}].object"
                    case t:
                        val = f"args[{arg_i}].{t}"
                f_fields.append(ZigStructInit.Field(name=arg.name, value=val))

            f = ZigStructInit(None, f_fields)
            zs = ZigStructInit(
                "Event",
                [ZigStructInit.Field(name=e.name, value=f.zig_it())],
            )

            if f_fields:
                return zs.zig_it()
            else:
                return f'Event.@"{e.name}"'

        switch_cases = [(str(i), getv(e)) for i, e in enumerate(self.events.values())]
        switch_cases.append(("else", "unreachable"))

        args_is_unused = all(not e.args for e in self.events.values())
        return ZigFn(
            "from_args",
            args=[
                ("opcode", "u16"),
                ("_" if args_is_unused else "args", "[]Argument"),
            ],
            return_type="Event",
            body=ZigReturn(ZigSwitch("opcode", switch_cases)),
        )

    def emit(self, fd: TextIO):
        emit_comment(self.description, fd)

        name_camel = "".join(w.capitalize() for w in self.name.split("_"))
        fd.write(
            f"""pub const {name_camel} = enum(u32) {{
            _,
            """
        )

        fd.write(self.interface_impl())

        for enum in self.enums.values():
            enum.emit(fd)

        if self.events:
            ev_asgn = ZigAssignment(
                name="Event",
                value=ZigUnion(
                    [e.zig_union_variant() for e in self.events.values()],
                    extra=[self.from_args_fn()],
                ),
            )
            fd.write(ev_asgn.zig_it())

        req_asgn = ZigAssignment(
            name="Request",
            value=ZigUnion(
                [e.zig_union_variant() for e in self.requests.values()],
                extra=[
                    ZigFn(
                        "ReturnType",
                        args=[
                            ("request", "std.meta.Tag(Request)"),
                        ],
                        return_type="type",
                        body=ZigReturn(
                            ZigSwitch(
                                "request",
                                variants=[
                                    ("." + e.name, e.zig_return_type())
                                    for _, e in enumerate(self.requests.values())
                                ],
                            )
                        ),
                    )
                ],
            ),
        )

        fd.write(req_asgn.zig_it())

        fd.write("};\n")


@dataclass(slots=True)
class Protocol:
    copyright: str = field(repr=False)
    name: str
    interfaces: dict[str, Interface]
    prefix: str
    globals: list[str] = field(repr=False)

    def __init__(self, file: Path, parent: Protocol | None = None):
        tree = ET.parse(file)

        protocol = tree.getroot()
        assert protocol.tag == "protocol"

        self.interfaces = parent.interfaces if parent else {}
        self.name = protocol.get("name") or Never
        self.globals = []

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
        prefix = name.split("_")[0]
        ns = Namespace.get(prefix)
        interface = ns.find_interface(name)
        assert interface

        if prefix not in self.globals:
            self.globals.append(prefix)

        return interface

    def emit(self, fd: TextIO):
        emit_comment(self.copyright, fd, r"//")

        # for g in self.globals:
        #     fd.write(
        #         f"""
        #     const {g.prefix} = @import("{g.prefix}.zig");"""
        #     )
        # fd.write("\n")

        for i in self.interfaces.values():
            i.emit(fd)


@dataclass(slots=True)
class Namespace:
    instances: ClassVar[dict[str, Namespace]] = {}
    name: str
    protocols: list[Protocol] = field(repr=False)

    @classmethod
    def get(cls, prefix: str) -> Namespace:
        return cls.instances.setdefault(prefix, Namespace(prefix, []))

    def find_interface(self, name: str) -> Interface | None:
        for protocol in self.protocols:
            if interface := protocol.interfaces.get(name):
                return interface

    def emit(self, fd: TextIO):

        for p in self.protocols:
            p.emit(fd)

        fd.write(
            """\
            const std = @import("std");
            const os = std.os;
            const Proxy = @import("../proxy.zig").Proxy;
            const Interface = @import("../proxy.zig").Interface;
            const Argument = @import("../argument.zig").Argument;
            const Fixed = @import("../argument.zig").Fixed;
            const Client = @import("../client.zig").Client;

            """
        )

        globals_deduped: set[str] = set()
        for p in self.protocols:
            globals_deduped.update(p.globals)

        for g in globals_deduped:
            fd.write(
                f"""
            const {g} = @import("{g}.zig");"""
            )

script_dir = Path(__file__).parent

def main():
    global protocols
    xml_protocols = [
        "/usr/share/wayland/wayland.xml",
        "/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml",
        script_dir / "./protocols/wlr-layer-shell-unstable-v1.xml",
        "/usr/share/wayland-protocols/unstable/tablet/tablet-unstable-v2.xml",
        "/usr/share/wayland-protocols/staging/cursor-shape/cursor-shape-v1.xml",
        "/usr/share/wayland-protocols/unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml",
        # "/usr/share/wayland-protocols/stable/presentation-time/presentation-time.xml",
        # "/usr/share/wayland-protocols/stable/viewporter/viewporter.xml",
    ]
    for p in xml_protocols:
        p = Protocol(Path(p))
        Namespace.get(p.prefix).protocols.append(p)

    for ns in Namespace.instances.values():
        out =  script_dir / f"generated/{ns.name}.zig"
        out.parent.mkdir(exist_ok=True)
        with out.open("w") as f:
            ns.emit(f)
        pprint(ns)

        subprocess.run(["zig", "fmt", str(out)], check=True)


if __name__ == "__main__":
    main()
