const std = @import("std");

pub fn readAll(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(name, .{});
    defer file.close();

    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}
