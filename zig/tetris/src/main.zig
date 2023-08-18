const app = @import("app.zig");

pub fn main() !void {
    var tetris = app.Tetris.new();
    tetris.run();
}
