const std = @import("std");

pub const Font = struct {
    info: Info,
    common: Common,
    pages: []const []const u8,
    chars: []const Char,
    kerningPairs: []const KerningPair,
};

pub const Info = struct {
    fontSize: i16,
    bitField: u8,
    charSet: u8,
    stretchH: u16,
    aa: u8,
    paddingUp: u8,
    paddingRight: u8,
    paddingDown: u8,
    paddingLeft: u8,
    spacingHoriz: u8,
    spacingVert: u8,
    outline: u8,
    name: []const u8 = &.{},
};

pub const Common = struct {
    lineHeight: u16,
    base: u16,
    scaleW: u16,
    scaleH: u16,
    pages: u16,
    bitField: u8,
    alphaChnl: u8,
    redChnl: u8,
    greenChnl: u8,
    blueChnl: u8,
};

pub const Char = struct {
    id: u32,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    xOffset: i16,
    yOffset: i16,
    xAdvance: i16,
    page: u8,
    chnl: u8,
};

pub const KerningPair = struct { first: u32, second: u32, amount: i16 };
