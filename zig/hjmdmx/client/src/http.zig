const std = @import("std");

var client: std.http.Client = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    client = std.http.Client{ .allocator = alloc };
}

pub fn deinit() void {
    client.deinit();
}

pub fn sendValue(T: type, url: []const u8, value: ?T) T {
    var buffer: [16]u8 = undefined;

    var response: std.ArrayListUnmanaged(u8) = .initBuffer(&buffer);

    const status = client.fetch(.{
        .method = .POST,
        .payload = if (value == null) null else &std.mem.toBytes(value),
        .location = .{ .url = url },
        .response_storage = .{ .static = &response },
    }) catch unreachable;

    if (status.status != .ok)
        std.debug.panic("request error: {}", .{status.status});

    return std.mem.bytesToValue(T, response.items);
}

pub fn sendAlloc(alloc: std.mem.Allocator, url: []const u8) std.ArrayList(u8) {
    var response: std.ArrayList(u8) = .init(alloc);

    const status = client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &response },
    }) catch unreachable;

    if (status.status != .ok)
        std.debug.panic("request error: {}", .{status.status});

    return response;
}
