const std = @import("std");

// 定义地图的类型
const MapItem = enum(u8) {
    SPACE = ' ',
    WALL = '#',
    GOAL = '.',
    BLOCK = 'o',
    BLOCK_ON_GOAL = 'O',
    MAN = 'p',
    MAN_ON_GOAL = 'P',

    fn fromInt(value: u8) MapItem {
        return @enumFromInt(value);
    }

    fn toInt(self: MapItem) u8 {
        return @intFromEnum(self);
    }
};

// 定义地图
const stageMap =
    \\########
    \\# .. p #
    \\# oo   #
    \\#      #
    \\########
;

const stageWidth = 8;
const stageHeight = 5;
const stageLength = stageHeight * stageWidth;

pub fn main() void {

    // 初始化地图
    var state: [stageLength]MapItem = undefined;
    initialize(&state, stageMap);

    const stdin = std.io.getStdIn().reader();

    while (true) {

        // 画出游戏地图
        draw(&state);
        // 检查游戏胜利条件
        if (checkClear(&state)) break;

        std.debug.print("a:left d:right w:up s:down. command?\n", .{});
        // 获取用户输入
        const char = inputChar(stdin);
        // 根据输入更新游戏地图
        update(&state, char);
    }

    // 游戏胜利
    std.debug.print("Congratulation's! you win.\n", .{});
}

fn initialize(stage: []MapItem, map: []const u8) void {
    var index: usize = 0;
    for (map) |value| {
        if (value == '\n') continue;

        stage[index] = MapItem.fromInt(value);
        index += 1;
    }
}

fn draw(stage: []MapItem) void {
    for (0..stageHeight) |y| {
        for (0..stageWidth) |x| {
            const item = stage[y * stageWidth + x].toInt();
            std.debug.print("{c}", .{item});
        }
        std.debug.print("\n", .{});
    }
}

fn checkClear(stage: []MapItem) bool {
    for (stage) |value| {
        if (value == MapItem.BLOCK) {
            return false;
        }
    }
    return true;
}

fn inputChar(reader: anytype) ?u8 {
    var buffer: [2]u8 = undefined;
    const input = reader.readUntilDelimiterOrEof(buffer[0..], '\n') //
    catch null orelse return null;
    return if (input.len != 1) null else input[0];
}

fn update(state: []MapItem, input: ?u8) void {
    const char = input orelse return;

    // 操作角色移动的距离
    const delta: isize = switch (char) {
        'w' => -stageWidth,
        's' => stageWidth,
        'd' => 1,
        'a' => -1,
        else => return,
    };

    // 角色当前位置
    const currentIndex = for (state, 0..) |value, index| {
        if (value == MapItem.MAN or value == MapItem.MAN_ON_GOAL) break index;
    } else return;

    const index = @as(isize, @intCast(currentIndex)) + delta;
    if (index < 0 or index > stageLength) return;

    // 角色欲前往的目的地
    const destIndex = @as(usize, @intCast(index));
    updatePlayer(state, currentIndex, destIndex, delta);
}

fn updatePlayer(state: []MapItem, current: usize, dest: usize, delta: isize) void {
    if (state[dest] == .SPACE or state[dest] == .GOAL) {
        // 如果是空地或者目标地，则可以移动
        state[dest] = if (state[dest] == .GOAL) .MAN_ON_GOAL else .MAN;
        state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
    } else if (state[dest] == .BLOCK or state[dest] == .BLOCK_ON_GOAL) {
        //  如果是箱子或者目的地上的箱子，需要考虑该方向上的第二个位置
        const index = @as(isize, @intCast(dest)) + delta;
        if (index < 0 or index > stageLength) return;

        const next = @as(usize, @intCast(index));
        if (state[next] == .SPACE or state[next] == .GOAL) {
            state[next] = if (state[next] == .GOAL) .BLOCK_ON_GOAL else .BLOCK;
            state[dest] = if (state[dest] == .BLOCK_ON_GOAL) .MAN_ON_GOAL else .MAN;
            state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
        }
    }
}
