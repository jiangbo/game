const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");

const cursor = @import("cursor.zig");
const scene = @import("scene.zig");

const Region = @This();

pub const pickType = gfx.Texture;

pub const RegionType = enum {
    deliver,
    cola,
    sprite,
    takeoutBoxBundle,
    meatBallBox,
    braisedChickenBox,
    redCookedPorkBox,
    microWave,
    takeoutBox,
};

type: RegionType,
area: math.Rectangle,
texture: ?gfx.Texture = null,
meal: ?cursor.Meal = null,
timer: ?window.Timer = null,

// 外卖员专有字段
wanted: ?std.BoundedArray(cursor.Meal, 10) = null,
waitedTime: f32 = math.epsilon, // 外卖员已经等待的时间

const DELIVER_TIMEOUT = 40; // 外卖员耐心超时秒数
const DRINKS_PER_LINE = 2; // 每行 2 个饮料
const DELIVER_TOTAL_LINES = 4; // 总共 4 行外卖

pub fn init(x: f32, y: f32, regionType: RegionType) Region {
    const position: math.Vector = .init(x, y);

    var self: Region = .{ .area = .{}, .type = regionType };
    switch (regionType) {
        .deliver => refreshDeliver(&self),

        .cola => {
            self.texture = gfx.loadTexture("assets/cola_bundle.png");
            self.meal = .init(.cola);
        },

        .sprite => {
            self.texture = gfx.loadTexture("assets/sprite_bundle.png");
            self.meal = .init(.sprite);
        },

        .takeoutBoxBundle => {
            self.texture = gfx.loadTexture("assets/tb_bundle.png");
            self.meal = .init(.takeoutBox);
        },

        .meatBallBox => {
            self.texture = gfx.loadTexture("assets/mb_box_bundle.png");
            self.meal = .init(.meatBallBox);
        },

        .braisedChickenBox => {
            self.texture = gfx.loadTexture("assets/bc_box_bundle.png");
            self.meal = .init(.braisedChickenBox);
        },

        .redCookedPorkBox => {
            self.texture = gfx.loadTexture("assets/rcp_box_bundle.png");
            self.meal = .init(.redCookedPorkBox);
        },

        .microWave => {
            self.texture = gfx.loadTexture("assets/mo_opening.png");
        },
        .takeoutBox => {
            self.area = .init(position, .{ .x = 92, .y = 100 });
        },
    }

    if (self.texture) |texture| {
        self.area = .init(position, texture.size());
    }

    return self;
}

fn refreshDeliver(self: *Region) void {
    // 随机外卖员形象
    const meituan = math.rand.boolean();
    if (meituan) {
        self.texture = gfx.loadTexture("assets/meituan.png");
    } else {
        self.texture = gfx.loadTexture("assets/eleme.png");
    }

    self.waitedTime = math.epsilon;

    // 随机要求餐品
    self.wanted = std.BoundedArray(cursor.Meal, 10).init(0) catch unreachable;
    const drinks = math.randU8(0, 7); // 随机 0 到 7 个饮料
    const lines = (drinks + DRINKS_PER_LINE - 1) / DRINKS_PER_LINE;

    // 先加菜品
    for (0..DELIVER_TOTAL_LINES - lines) |_| {
        // 随机要求菜品
        const meal: cursor.Meal = switch (math.randU8(0, 2)) {
            0 => .init(.braisedChickenHot),
            1 => .init(.meatBallHot),
            2 => .init(.redCookedPorkHot),
            else => unreachable,
        };
        self.wanted.?.appendAssumeCapacity(meal);
    }

    // 再加饮料
    for (0..drinks) |_| {
        if (math.rand.boolean())
            self.wanted.?.appendAssumeCapacity(.init(.cola))
        else
            self.wanted.?.appendAssumeCapacity(.init(.sprite));
    }
}

fn hiddenDeliver(self: *Region) void {
    self.wanted = null;
    self.texture = null;
    self.waitedTime = math.epsilon;
    self.timer = .init(math.randF32(10, 20));
}

pub fn updateDeliver(self: *Region, delta: f32) void {
    if (self.wanted == null) return;

    self.waitedTime += delta;
    if (self.waitedTime >= DELIVER_TIMEOUT)
        self.hiddenDeliver();
}

pub fn pick(self: *Region) void {
    cursor.picked = self.meal;
    scene.returnPosition = cursor.position;
    scene.pickedMeal = cursor.picked;
    scene.pickedRegion = self;

    if (self.type == .takeoutBox) {
        self.meal = null;
        scene.returnPosition = self.area.min;
    }
    if (self.type == .microWave) {
        self.meal = null;
        scene.returnPosition = self.area.min.add(.{ .x = 113, .y = 65 });
    }
}

pub fn place(self: *Region) void {
    if (self.type == .takeoutBox) return self.placeInTakeoutBox();
    if (self.type == .microWave) return self.placeInMicroWave();
    if (self.type == .deliver) return self.placeInDeliver();

    if (self.meal) |meal| {
        if (meal.type == cursor.picked.?.type) {
            cursor.picked = null;
        }
    }
}

pub fn placeInTakeoutBox(self: *Region) void {
    if (self.meal == null) {
        switch (cursor.picked.?.type) {
            .cola, .sprite, .meatBallBox => {},
            .braisedChickenBox, .redCookedPorkBox => {},
            else => {
                self.meal = cursor.picked;
                cursor.picked = null;
            },
        }
        return;
    }

    if (self.meal.?.type == .takeoutBox) {
        self.meal = switch (cursor.picked.?.type) {
            .braisedChickenBox => .init(.braisedChickenCold),
            .meatBallBox => .init(.meatBallCold),
            .redCookedPorkBox => .init(.redCookedPorkCold),
            else => return,
        };
        cursor.picked = null;
    }
}

pub fn placeInMicroWave(self: *Region) void {
    if (self.meal != null) return;

    self.meal = switch (cursor.picked.?.type) {
        .braisedChickenCold => .init(.braisedChickenHot),
        .meatBallCold => .init(.meatBallHot),
        .redCookedPorkCold => .init(.redCookedPorkHot),
        else => return,
    };
    cursor.picked = null;
    audio.playSound("assets/mo_working.ogg");
    self.texture = gfx.loadTexture("assets/mo_working.png");
    self.timer = .init(9);
}

pub fn placeInDeliver(self: *Region) void {
    if (self.wanted == null) return;

    const cursorType = cursor.picked.?.type;
    for (self.wanted.?.slice()) |*meal| {
        if (meal.type == cursorType and !meal.done) {
            cursor.picked = null;
            meal.done = true;
            audio.playSound("assets/complete.ogg");
            break;
        }
    }

    // 检查是否全部完成
    for (self.wanted.?.slice()) |meal| if (!meal.done) return;

    self.hiddenDeliver();
}

pub fn timerFinished(self: *Region) void {
    if (self.type == .microWave) {
        self.texture = gfx.loadTexture("assets/mo_opening.png");
        audio.playSound("assets/mo_complete.ogg");
    }

    if (self.type == .deliver) refreshDeliver(self);

    self.timer = null;
}

pub fn renderDeliver(self: *const Region) void {
    if (self.wanted == null) return;

    var pos = self.area.min.add(.{ .x = -35, .y = 15 });

    // 耐心条的边框
    gfx.draw(gfx.loadTexture("assets/patience_border.png"), pos);

    const percent: f32 = self.waitedTime / DELIVER_TIMEOUT;

    // 耐心条的长度
    const content = gfx.loadTexture("assets/patience_content.png");
    var dst: math.Rectangle = .init(pos, content.size());
    dst.min.y = dst.max.y - content.height() * percent;
    var src: math.Rectangle = .init(.zero, content.size());
    src.min.y = src.max.y - content.height() * percent;
    gfx.drawOptions(content, .{ .sourceRect = src, .targetRect = dst });

    // 对话框
    pos = self.area.min.add(.{ .x = 175, .y = 55 });
    gfx.draw(gfx.loadTexture("assets/bubble.png"), pos);

    var drinks: u8 = 0;
    for (self.wanted.?.slice(), 0..) |meal, i| {
        const index: f32 = @floatFromInt(i);
        if (meal.type == .cola or meal.type == .sprite) {
            // 所有食物放置后的偏移
            const mealOffsetY = 32 * (i - drinks) + 10;
            const drinkOffsetY = 28 * (drinks / DRINKS_PER_LINE); // 饮料本身的偏移
            const offsetY: f32 = @floatFromInt(mealOffsetY + drinkOffsetY);
            var offset: math.Vector = .init(18, offsetY);

            if (drinks % DRINKS_PER_LINE != 0) offset.x += 32; // 饮料并排放置

            gfx.drawOptions(meal.icon, .{
                .targetRect = .init(pos.add(offset), .init(20, 26)),
                .alpha = if (meal.done) 0.35 else 1,
            });

            drinks += 1;
            continue;
        }

        const offset: math.Vector = .init(18, 32 * index + 5);
        gfx.drawOptions(meal.icon, .{
            .targetRect = .init(pos.add(offset), .init(45, 25)),
            .alpha = if (meal.done) 0.35 else 1,
        });
    }
}
