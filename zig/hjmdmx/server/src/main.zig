const std = @import("std");
const http = @import("http");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var server = try http.Server(void).init(allocator, .{ .port = 4444 }, {});
    defer {
        server.stop();
        server.deinit();
    }

    var router = try server.router(.{});
    router.post("/api/login", login, .{});
    router.post("/api/logout", logout, .{});
    router.post("/api/text", text, .{});
    router.post("/api/update1", update1, .{});
    router.post("/api/update2", update2, .{});

    std.log.info("start http server", .{});

    try server.listen();
}

const fileText: []const u8 = @embedFile("text.txt");
var mutex: std.Thread.Mutex = .{};

var progress1: f32 = -1;
var progress2: f32 = -1;

fn login(_: *http.Request, res: *http.Response) !void {
    mutex.lock();
    defer mutex.unlock();

    if (progress1 >= 0 and progress2 >= 0) {
        res.status = 403;
        return;
    }

    var result: i32 = 0;
    if (progress1 < 0) {
        progress1 = 0;
        std.log.info("player1 online", .{});
        result = 1;
    } else if (progress2 < 0) {
        progress2 = 0;
        std.log.info("player2 online", .{});
        result = 2;
    }

    res.status = 200;
    try res.writer().writeAll(&std.mem.toBytes(result));
}

fn logout(req: *http.Request, res: *http.Response) !void {
    mutex.lock();
    defer mutex.unlock();

    if (req.body()) |body| {
        const value = std.mem.bytesToValue(i32, body);
        if (value == 1) {
            progress1 = -1;
            std.log.info("player1 offline", .{});
        } else if (value == 2) {
            progress2 = -1;
            std.log.info("player2 offline", .{});
        }
    }
    try res.writer().writeAll(req.body().?);
}

fn text(_: *http.Request, res: *http.Response) !void {
    try res.writer().writeAll(fileText);
}

fn update1(req: *http.Request, res: *http.Response) !void {
    mutex.lock();
    defer mutex.unlock();

    progress1 = std.mem.bytesToValue(f32, req.body().?);
    std.log.info("player1 progress: {d}", .{progress1});
    try res.writer().writeAll(&std.mem.toBytes(progress2));
}

fn update2(req: *http.Request, res: *http.Response) !void {
    mutex.lock();
    defer mutex.unlock();

    progress2 = std.mem.bytesToValue(f32, req.body().?);
    std.log.info("player2 progress: {d}", .{progress2});
    try res.writer().writeAll(&std.mem.toBytes(progress1));
}
