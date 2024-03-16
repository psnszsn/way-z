const Color = @This();
const std = @import("std");

pub const default = NamedColor.grey;

value: u32,

pub const NamedColor = struct {
    pub const black = fromRGB(0x000000);
    pub const silver = fromRGB(0xc0c0c0);
    pub const gray = fromRGB(0x808080);
    pub const white = fromRGB(0xffffff);
    pub const maroon = fromRGB(0x800000);
    pub const red = fromRGB(0xff0000);
    pub const purple = fromRGB(0x800080);
    pub const fuchsia = fromRGB(0xff00ff);
    pub const green = fromRGB(0x008000);
    pub const lime = fromRGB(0x00ff00);
    pub const olive = fromRGB(0x808000);
    pub const yellow = fromRGB(0xffff00);
    pub const navy = fromRGB(0x000080);
    pub const blue = fromRGB(0x0000ff);
    pub const teal = fromRGB(0x008080);
    pub const aqua = fromRGB(0x00ffff);
    pub const orange = fromRGB(0xffa500);
    pub const aliceblue = fromRGB(0xf0f8ff);
    pub const antiquewhite = fromRGB(0xfaebd7);
    pub const aquamarine = fromRGB(0x7fffd4);
    pub const azure = fromRGB(0xf0ffff);
    pub const beige = fromRGB(0xf5f5dc);
    pub const bisque = fromRGB(0xffe4c4);
    pub const blanchedalmond = fromRGB(0xffebcd);
    pub const blueviolet = fromRGB(0x8a2be2);
    pub const brown = fromRGB(0xa52a2a);
    pub const burlywood = fromRGB(0xdeb887);
    pub const cadetblue = fromRGB(0x5f9ea0);
    pub const chartreuse = fromRGB(0x7fff00);
    pub const chocolate = fromRGB(0xd2691e);
    pub const coral = fromRGB(0xff7f50);
    pub const cornflowerblue = fromRGB(0x6495ed);
    pub const cornsilk = fromRGB(0xfff8dc);
    pub const crimson = fromRGB(0xdc143c);
    pub const cyan = fromRGB(0x00ffff);
    pub const darkblue = fromRGB(0x00008b);
    pub const darkcyan = fromRGB(0x008b8b);
    pub const darkgoldenrod = fromRGB(0xb8860b);
    pub const darkgray = fromRGB(0xa9a9a9);
    pub const darkgreen = fromRGB(0x006400);
    pub const darkgrey = fromRGB(0xa9a9a9);
    pub const darkkhaki = fromRGB(0xbdb76b);
    pub const darkmagenta = fromRGB(0x8b008b);
    pub const darkolivegreen = fromRGB(0x556b2f);
    pub const darkorange = fromRGB(0xff8c00);
    pub const darkorchid = fromRGB(0x9932cc);
    pub const darkred = fromRGB(0x8b0000);
    pub const darksalmon = fromRGB(0xe9967a);
    pub const darkseagreen = fromRGB(0x8fbc8f);
    pub const darkslateblue = fromRGB(0x483d8b);
    pub const darkslategray = fromRGB(0x2f4f4f);
    pub const darkslategrey = fromRGB(0x2f4f4f);
    pub const darkturquoise = fromRGB(0x00ced1);
    pub const darkviolet = fromRGB(0x9400d3);
    pub const deeppink = fromRGB(0xff1493);
    pub const deepskyblue = fromRGB(0x00bfff);
    pub const dimgray = fromRGB(0x696969);
    pub const dimgrey = fromRGB(0x696969);
    pub const dodgerblue = fromRGB(0x1e90ff);
    pub const firebrick = fromRGB(0xb22222);
    pub const floralwhite = fromRGB(0xfffaf0);
    pub const forestgreen = fromRGB(0x228b22);
    pub const gainsboro = fromRGB(0xdcdcdc);
    pub const ghostwhite = fromRGB(0xf8f8ff);
    pub const gold = fromRGB(0xffd700);
    pub const goldenrod = fromRGB(0xdaa520);
    pub const greenyellow = fromRGB(0xadff2f);
    pub const grey = fromRGB(0x808080);
    pub const honeydew = fromRGB(0xf0fff0);
    pub const hotpink = fromRGB(0xff69b4);
    pub const indianred = fromRGB(0xcd5c5c);
    pub const indigo = fromRGB(0x4b0082);
    pub const ivory = fromRGB(0xfffff0);
    pub const khaki = fromRGB(0xf0e68c);
    pub const lavender = fromRGB(0xe6e6fa);
    pub const lavenderblush = fromRGB(0xfff0f5);
    pub const lawngreen = fromRGB(0x7cfc00);
    pub const lemonchiffon = fromRGB(0xfffacd);
    pub const lightblue = fromRGB(0xadd8e6);
    pub const lightcoral = fromRGB(0xf08080);
    pub const lightcyan = fromRGB(0xe0ffff);
    pub const lightgoldenrodyellow = fromRGB(0xfafad2);
    pub const lightgray = fromRGB(0xd3d3d3);
    pub const lightgreen = fromRGB(0x90ee90);
    pub const lightgrey = fromRGB(0xd3d3d3);
    pub const lightpink = fromRGB(0xffb6c1);
    pub const lightsalmon = fromRGB(0xffa07a);
    pub const lightseagreen = fromRGB(0x20b2aa);
    pub const lightskyblue = fromRGB(0x87cefa);
    pub const lightslategray = fromRGB(0x778899);
    pub const lightslategrey = fromRGB(0x778899);
    pub const lightsteelblue = fromRGB(0xb0c4de);
    pub const lightyellow = fromRGB(0xffffe0);
    pub const limegreen = fromRGB(0x32cd32);
    pub const linen = fromRGB(0xfaf0e6);
    pub const magenta = fromRGB(0xff00ff);
    pub const mediumaquamarine = fromRGB(0x66cdaa);
    pub const mediumblue = fromRGB(0x0000cd);
    pub const mediumorchid = fromRGB(0xba55d3);
    pub const mediumpurple = fromRGB(0x9370db);
    pub const mediumseagreen = fromRGB(0x3cb371);
    pub const mediumslateblue = fromRGB(0x7b68ee);
    pub const mediumspringgreen = fromRGB(0x00fa9a);
    pub const mediumturquoise = fromRGB(0x48d1cc);
    pub const mediumvioletred = fromRGB(0xc71585);
    pub const midnightblue = fromRGB(0x191970);
    pub const mintcream = fromRGB(0xf5fffa);
    pub const mistyrose = fromRGB(0xffe4e1);
    pub const moccasin = fromRGB(0xffe4b5);
    pub const navajowhite = fromRGB(0xffdead);
    pub const oldlace = fromRGB(0xfdf5e6);
    pub const olivedrab = fromRGB(0x6b8e23);
    pub const orangered = fromRGB(0xff4500);
    pub const orchid = fromRGB(0xda70d6);
    pub const palegoldenrod = fromRGB(0xeee8aa);
    pub const palegreen = fromRGB(0x98fb98);
    pub const paleturquoise = fromRGB(0xafeeee);
    pub const palevioletred = fromRGB(0xdb7093);
    pub const papayawhip = fromRGB(0xffefd5);
    pub const peachpuff = fromRGB(0xffdab9);
    pub const peru = fromRGB(0xcd853f);
    pub const pink = fromRGB(0xffc0cb);
    pub const plum = fromRGB(0xdda0dd);
    pub const powderblue = fromRGB(0xb0e0e6);
    pub const rosybrown = fromRGB(0xbc8f8f);
    pub const royalblue = fromRGB(0x4169e1);
    pub const saddlebrown = fromRGB(0x8b4513);
    pub const salmon = fromRGB(0xfa8072);
    pub const sandybrown = fromRGB(0xf4a460);
    pub const seagreen = fromRGB(0x2e8b57);
    pub const seashell = fromRGB(0xfff5ee);
    pub const sienna = fromRGB(0xa0522d);
    pub const skyblue = fromRGB(0x87ceeb);
    pub const slateblue = fromRGB(0x6a5acd);
    pub const slategray = fromRGB(0x708090);
    pub const slategrey = fromRGB(0x708090);
    pub const snow = fromRGB(0xfffafa);
    pub const springgreen = fromRGB(0x00ff7f);
    pub const steelblue = fromRGB(0x4682b4);
    pub const tan = fromRGB(0xd2b48c);
    pub const thistle = fromRGB(0xd8bfd8);
    pub const tomato = fromRGB(0xff6347);
    pub const turquoise = fromRGB(0x40e0d0);
    pub const violet = fromRGB(0xee82ee);
    pub const wheat = fromRGB(0xf5deb3);
    pub const whitesmoke = fromRGB(0xf5f5f5);
    pub const yellowgreen = fromRGB(0x9acd32);
    pub const rebeccapurple = fromRGB(0x663399);
    pub const transparent = fromU32(0x00000000);
};

const Theme = struct {
    background: Color,
    shadow: Color,
    light: Color,
    border: Color,
    select: Color,
    focus: Color,
};

pub var theme = Theme{
    .background = fromRGBsep(224, 224, 224),
    .shadow = fromRGBsep(170, 170, 170),
    .light = fromRGBsep(255, 255, 255),
    .border = fromRGBsep(85, 85, 85),
    .select = fromRGBAsep(0, 120, 247, 102),
    // .select = fromRGBsep(0, 120, 247),
    .focus = fromRGBsep(85, 160, 230),
};

pub fn fromU32(value: u32) Color {
    return Color{
        .value = value,
    };
}

pub fn fromRGB(rgb: u32) Color {
    return Color{ .value = rgb | 0xff000000 };
}

pub fn fromRGBsep(r: u8, g: u8, b: u8) Color {
    return fromRGBAsep(r, g, b, 0xff);
}

pub fn fromRGBAsep(r: u8, g: u8, b: u8, a: u8) Color {
    const v: u32 = (@as(u32, a) << @as(std.math.Log2Int(u32), @intCast(24))) |
        (@as(u32, r) << @as(std.math.Log2Int(u32), @intCast(16))) |
        (@as(u32, g) << @as(std.math.Log2Int(u32), @intCast(8))) |
        @as(u32, b);

    return Color{ .value = v };
}

pub fn getRed(self: Color) u32 {
    return (self.value >> 16) & 0xff;
}
pub fn getGreen(self: Color) u32 {
    return (self.value >> 8) & 0xff;
}
pub fn getBlue(self: Color) u32 {
    return self.value & 0xff;
}
pub fn getAlpha(self: Color) u32 {
    return (self.value >> 24) & 0xff;
}

pub fn setAlpha(self: *Color, value: u8) void {
    self.value &= 0x00ffffff;
    self.value |= @as(u32, value) << @as(std.math.Log2Int(u32), @intCast(24));
}

pub fn withAlpha(self: Color, value: u8) Color {
    var color = self;
    color.setAlpha(value);
    return color;
}

pub fn fromString(string: []const u8) Color {
    if (std.mem.eql(u8, string, "transparent")) {
        return Color{ .value = 0x00000000 };
    }

    inline for (comptime std.meta.declarations(NamedColor)) |c| {
        if (std.mem.eql(u8, string, c.name)) {
            return @field(NamedColor, c.name);
        }
    }

    return Color{ .value = 0x99999999 };
}
