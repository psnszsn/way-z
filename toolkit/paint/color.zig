// const Color = @This();
const std = @import("std");

pub const ColorS = packed struct(u32) {
    b: u8,
    g: u8,
    r: u8,
    a: u8 = 0xff,
};

pub const Color = enum(u32) {
    pub const default = Color.gray;
    pub var theme = Theme{
        .background = ggray(224),
        .shadow = ggray(170),
        .light = ggray(255),
        .border = ggray(85),
        .select = sep(.{ .r = 0, .g = 120, .b = 247, .a = 102 }),
        // .select = sep(0, 120, 247),
        .focus = sep(.{ .r = 85, .g = 160, .b = 230 }),
    };
    black = 0xff000000,
    silver = 0xffc0c0c0,
    gray = 0xff808080,
    white = 0xffffffff,
    maroon = 0xff800000,
    red = 0xffff0000,
    purple = 0xff800080,
    // fuchsia = 0xffff00ff,
    green = 0xff008000,
    lime = 0xff00ff00,
    olive = 0xff808000,
    yellow = 0xffffff00,
    navy = 0xff000080,
    blue = 0xff0000ff,
    teal = 0xff008080,
    // aqua = 0xff00ffff,
    orange = 0xffffa500,
    aliceblue = 0xfff0f8ff,
    antiquewhite = 0xfffaebd7,
    aquamarine = 0xff7fffd4,
    azure = 0xfff0ffff,
    beige = 0xfff5f5dc,
    bisque = 0xffffe4c4,
    blanchedalmond = 0xffffebcd,
    blueviolet = 0xff8a2be2,
    brown = 0xffa52a2a,
    burlywood = 0xffdeb887,
    cadetblue = 0xff5f9ea0,
    chartreuse = 0xff7fff00,
    chocolate = 0xffd2691e,
    coral = 0xffff7f50,
    cornflowerblue = 0xff6495ed,
    cornsilk = 0xfffff8dc,
    crimson = 0xffdc143c,
    cyan = 0xff00ffff,
    darkblue = 0xff00008b,
    darkcyan = 0xff008b8b,
    darkgoldenrod = 0xffb8860b,
    darkgray = 0xffa9a9a9,
    darkgreen = 0xff006400,
    // darkgrey = 0xffa9a9a9,
    darkkhaki = 0xffbdb76b,
    darkmagenta = 0xff8b008b,
    darkolivegreen = 0xff556b2f,
    darkorange = 0xffff8c00,
    darkorchid = 0xff9932cc,
    darkred = 0xff8b0000,
    darksalmon = 0xffe9967a,
    darkseagreen = 0xff8fbc8f,
    darkslateblue = 0xff483d8b,
    darkslategray = 0xff2f4f4f,
    // darkslategrey = 0xff2f4f4f,
    darkturquoise = 0xff00ced1,
    darkviolet = 0xff9400d3,
    deeppink = 0xffff1493,
    deepskyblue = 0xff00bfff,
    dimgray = 0xff696969,
    // dimgrey = 0xff696969,
    dodgerblue = 0xff1e90ff,
    firebrick = 0xffb22222,
    floralwhite = 0xfffffaf0,
    forestgreen = 0xff228b22,
    gainsboro = 0xffdcdcdc,
    ghostwhite = 0xfff8f8ff,
    gold = 0xffffd700,
    goldenrod = 0xffdaa520,
    greenyellow = 0xffadff2f,
    // grey = 0xff808080,
    honeydew = 0xfff0fff0,
    hotpink = 0xffff69b4,
    indianred = 0xffcd5c5c,
    indigo = 0xff4b0082,
    ivory = 0xfffffff0,
    khaki = 0xfff0e68c,
    lavender = 0xffe6e6fa,
    lavenderblush = 0xfffff0f5,
    lawngreen = 0xff7cfc00,
    lemonchiffon = 0xfffffacd,
    lightblue = 0xffadd8e6,
    lightcoral = 0xfff08080,
    lightcyan = 0xffe0ffff,
    lightgoldenrodyellow = 0xfffafad2,
    lightgray = 0xffd3d3d3,
    lightgreen = 0xff90ee90,
    // lightgrey = 0xffd3d3d3,
    lightpink = 0xffffb6c1,
    lightsalmon = 0xffffa07a,
    lightseagreen = 0xff20b2aa,
    lightskyblue = 0xff87cefa,
    lightslategray = 0xff778899,
    // lightslategrey = 0xff778899,
    lightsteelblue = 0xffb0c4de,
    lightyellow = 0xffffffe0,
    limegreen = 0xff32cd32,
    linen = 0xfffaf0e6,
    magenta = 0xffff00ff,
    mediumaquamarine = 0xff66cdaa,
    mediumblue = 0xff0000cd,
    mediumorchid = 0xffba55d3,
    mediumpurple = 0xff9370db,
    mediumseagreen = 0xff3cb371,
    mediumslateblue = 0xff7b68ee,
    mediumspringgreen = 0xff00fa9a,
    mediumturquoise = 0xff48d1cc,
    mediumvioletred = 0xffc71585,
    midnightblue = 0xff191970,
    mintcream = 0xfff5fffa,
    mistyrose = 0xffffe4e1,
    moccasin = 0xffffe4b5,
    navajowhite = 0xffffdead,
    oldlace = 0xfffdf5e6,
    olivedrab = 0xff6b8e23,
    orangered = 0xffff4500,
    orchid = 0xffda70d6,
    palegoldenrod = 0xffeee8aa,
    palegreen = 0xff98fb98,
    paleturquoise = 0xffafeeee,
    palevioletred = 0xffdb7093,
    papayawhip = 0xffffefd5,
    peachpuff = 0xffffdab9,
    peru = 0xffcd853f,
    pink = 0xffffc0cb,
    plum = 0xffdda0dd,
    powderblue = 0xffb0e0e6,
    rosybrown = 0xffbc8f8f,
    royalblue = 0xff4169e1,
    saddlebrown = 0xff8b4513,
    salmon = 0xfffa8072,
    sandybrown = 0xfff4a460,
    seagreen = 0xff2e8b57,
    seashell = 0xfffff5ee,
    sienna = 0xffa0522d,
    skyblue = 0xff87ceeb,
    slateblue = 0xff6a5acd,
    slategray = 0xff708090,
    // slategrey = 0xff708090,
    snow = 0xfffffafa,
    springgreen = 0xff00ff7f,
    steelblue = 0xff4682b4,
    tan = 0xffd2b48c,
    thistle = 0xffd8bfd8,
    tomato = 0xffff6347,
    turquoise = 0xff40e0d0,
    violet = 0xffee82ee,
    wheat = 0xfff5deb3,
    whitesmoke = 0xfff5f5f5,
    yellowgreen = 0xff9acd32,
    rebeccapurple = 0xff663399,
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

const Theme = struct {
    background: Color,
    shadow: Color,
    light: Color,
    border: Color,
    select: Color,
    focus: Color,
};
