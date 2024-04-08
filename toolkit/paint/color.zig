// const Color = @This();
const std = @import("std");

pub const ColorS = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    a: u8 = 0xff,
};

pub const Color = enum(u32) {
    pub const default = Color.grey;
    pub var theme = Theme{
        .background = ggray(224),
        .shadow = ggray(170),
        .light = ggray(255),
        .border = ggray(85),
        .select = sep(.{ .r = 0, .g = 120, .b = 247, .a = 102 }),
        // .select = sep(0, 120, 247),
        .focus = sep(.{ .r = 85, .g = 160, .b = 230 }),
    };
    black = rgb(0x000000),
    silver = rgb(0xc0c0c0),
    // gray = rgb(0x808080),
    white = rgb(0xffffff),
    maroon = rgb(0x800000),
    red = rgb(0xff0000),
    purple = rgb(0x800080),
    // fuchsia = rgb(0xff00ff),
    green = rgb(0x008000),
    lime = rgb(0x00ff00),
    olive = rgb(0x808000),
    yellow = rgb(0xffff00),
    navy = rgb(0x000080),
    blue = rgb(0x0000ff),
    teal = rgb(0x008080),
    // aqua = rgb(0x00ffff),
    orange = rgb(0xffa500),
    aliceblue = rgb(0xf0f8ff),
    antiquewhite = rgb(0xfaebd7),
    aquamarine = rgb(0x7fffd4),
    azure = rgb(0xf0ffff),
    beige = rgb(0xf5f5dc),
    bisque = rgb(0xffe4c4),
    blanchedalmond = rgb(0xffebcd),
    blueviolet = rgb(0x8a2be2),
    brown = rgb(0xa52a2a),
    burlywood = rgb(0xdeb887),
    cadetblue = rgb(0x5f9ea0),
    chartreuse = rgb(0x7fff00),
    chocolate = rgb(0xd2691e),
    coral = rgb(0xff7f50),
    cornflowerblue = rgb(0x6495ed),
    cornsilk = rgb(0xfff8dc),
    crimson = rgb(0xdc143c),
    cyan = rgb(0x00ffff),
    darkblue = rgb(0x00008b),
    darkcyan = rgb(0x008b8b),
    darkgoldenrod = rgb(0xb8860b),
    darkgray = rgb(0xa9a9a9),
    darkgreen = rgb(0x006400),
    // darkgrey = rgb(0xa9a9a9),
    darkkhaki = rgb(0xbdb76b),
    darkmagenta = rgb(0x8b008b),
    darkolivegreen = rgb(0x556b2f),
    darkorange = rgb(0xff8c00),
    darkorchid = rgb(0x9932cc),
    darkred = rgb(0x8b0000),
    darksalmon = rgb(0xe9967a),
    darkseagreen = rgb(0x8fbc8f),
    darkslateblue = rgb(0x483d8b),
    darkslategray = rgb(0x2f4f4f),
    // darkslategrey = rgb(0x2f4f4f),
    darkturquoise = rgb(0x00ced1),
    darkviolet = rgb(0x9400d3),
    deeppink = rgb(0xff1493),
    deepskyblue = rgb(0x00bfff),
    dimgray = rgb(0x696969),
    // dimgrey = rgb(0x696969),
    dodgerblue = rgb(0x1e90ff),
    firebrick = rgb(0xb22222),
    floralwhite = rgb(0xfffaf0),
    forestgreen = rgb(0x228b22),
    gainsboro = rgb(0xdcdcdc),
    ghostwhite = rgb(0xf8f8ff),
    gold = rgb(0xffd700),
    goldenrod = rgb(0xdaa520),
    greenyellow = rgb(0xadff2f),
    grey = rgb(0x808080),
    honeydew = rgb(0xf0fff0),
    hotpink = rgb(0xff69b4),
    indianred = rgb(0xcd5c5c),
    indigo = rgb(0x4b0082),
    ivory = rgb(0xfffff0),
    khaki = rgb(0xf0e68c),
    lavender = rgb(0xe6e6fa),
    lavenderblush = rgb(0xfff0f5),
    lawngreen = rgb(0x7cfc00),
    lemonchiffon = rgb(0xfffacd),
    lightblue = rgb(0xadd8e6),
    lightcoral = rgb(0xf08080),
    lightcyan = rgb(0xe0ffff),
    lightgoldenrodyellow = rgb(0xfafad2),
    lightgray = rgb(0xd3d3d3),
    lightgreen = rgb(0x90ee90),
    // lightgrey = rgb(0xd3d3d3),
    lightpink = rgb(0xffb6c1),
    lightsalmon = rgb(0xffa07a),
    lightseagreen = rgb(0x20b2aa),
    lightskyblue = rgb(0x87cefa),
    lightslategray = rgb(0x778899),
    // lightslategrey = rgb(0x778899),
    lightsteelblue = rgb(0xb0c4de),
    lightyellow = rgb(0xffffe0),
    limegreen = rgb(0x32cd32),
    linen = rgb(0xfaf0e6),
    magenta = rgb(0xff00ff),
    mediumaquamarine = rgb(0x66cdaa),
    mediumblue = rgb(0x0000cd),
    mediumorchid = rgb(0xba55d3),
    mediumpurple = rgb(0x9370db),
    mediumseagreen = rgb(0x3cb371),
    mediumslateblue = rgb(0x7b68ee),
    mediumspringgreen = rgb(0x00fa9a),
    mediumturquoise = rgb(0x48d1cc),
    mediumvioletred = rgb(0xc71585),
    midnightblue = rgb(0x191970),
    mintcream = rgb(0xf5fffa),
    mistyrose = rgb(0xffe4e1),
    moccasin = rgb(0xffe4b5),
    navajowhite = rgb(0xffdead),
    oldlace = rgb(0xfdf5e6),
    olivedrab = rgb(0x6b8e23),
    orangered = rgb(0xff4500),
    orchid = rgb(0xda70d6),
    palegoldenrod = rgb(0xeee8aa),
    palegreen = rgb(0x98fb98),
    paleturquoise = rgb(0xafeeee),
    palevioletred = rgb(0xdb7093),
    papayawhip = rgb(0xffefd5),
    peachpuff = rgb(0xffdab9),
    peru = rgb(0xcd853f),
    pink = rgb(0xffc0cb),
    plum = rgb(0xdda0dd),
    powderblue = rgb(0xb0e0e6),
    rosybrown = rgb(0xbc8f8f),
    royalblue = rgb(0x4169e1),
    saddlebrown = rgb(0x8b4513),
    salmon = rgb(0xfa8072),
    sandybrown = rgb(0xf4a460),
    seagreen = rgb(0x2e8b57),
    seashell = rgb(0xfff5ee),
    sienna = rgb(0xa0522d),
    skyblue = rgb(0x87ceeb),
    slateblue = rgb(0x6a5acd),
    slategray = rgb(0x708090),
    // slategrey = rgb(0x708090),
    snow = rgb(0xfffafa),
    springgreen = rgb(0x00ff7f),
    steelblue = rgb(0x4682b4),
    tan = rgb(0xd2b48c),
    thistle = rgb(0xd8bfd8),
    tomato = rgb(0xff6347),
    turquoise = rgb(0x40e0d0),
    violet = rgb(0xee82ee),
    wheat = rgb(0xf5deb3),
    whitesmoke = rgb(0xf5f5f5),
    yellowgreen = rgb(0x9acd32),
    rebeccapurple = rgb(0x663399),
    transparent = 0x00000000,
    _,
    pub fn sep(c: ColorS) Color {
        const s: u32 = @bitCast(c);
        return @enumFromInt(s);
    }
    pub fn ggray(val: u8) Color {
        return sep(.{ .r = val, .g = val, .b = val });
    }
};
pub fn rgb(rgb_value: u32) u32 {
    return rgb_value | 0xff000000;
}

const Theme = struct {
    background: Color,
    shadow: Color,
    light: Color,
    border: Color,
    select: Color,
    focus: Color,
};
