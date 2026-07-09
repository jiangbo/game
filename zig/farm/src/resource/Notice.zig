const zhu = @import("zhu");

pub const Entry = struct {
    timer: f32 = 0,
    text: []const u8 = &.{},
    buffer: [192]u8 = undefined,
};

entry: Entry = .{},

pub fn reset(self: *@This()) void {
    self.entry = .{};
}

pub fn show(self: *@This(), comptime fmt: []const u8, args: anytype) void {
    const current = &self.entry;
    current.text = zhu.format(&current.buffer, fmt, args);
    current.timer = 2.0;
}

pub fn state(self: *@This()) *Entry {
    return &self.entry;
}
