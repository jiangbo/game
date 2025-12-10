const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const player = @import("player.zig");
const enemy = @import("enemy.zig");
const title = @import("title.zig");
const end = @import("end.zig");

const Background = struct {
    texture: gfx.Texture,
    position: gfx.Vector,
    size: gfx.Vector,
    offset: f32,
    speed: f32,

    fn init(path: [:0]const u8, speed: f32) Background {
        var self: Background = std.mem.zeroes(Background);
        self.texture = gfx.loadTexture(path, .init(1000, 1000));
        self.size = self.texture.size().scale(0.5);
        self.speed = speed;
        return self;
    }

    fn update(self: *Background, delta: f32) void {
        self.offset += self.speed * delta;
        if (self.offset > 0) self.offset -= self.size.y;
    }

    fn draw(self: *const Background) void {
        var y = self.offset;
        // 填满 Y 轴
        while (y < window.logicSize.y) : (y += self.size.y) {
            var x: f32 = 0;
            // 填满 X 轴
            while (x < window.logicSize.x) : (x += self.size.x) {
                camera.drawOption(self.texture, .init(x, y), .{
                    .size = self.size,
                });
            }
        }
    }
};

var isHelp = false;
var isDebug = false;
var isPause = false;
var vertexBuffer: []camera.Vertex = undefined;

var far: Background = undefined; // 远景
var near: Background = undefined; // 近景

const sceneType = enum { title, game, end };
pub var currentScene: sceneType = .title;
pub var isTyping: bool = false;

pub fn init() void {
    const text = gfx.loadTexture("assets/font/font.png", .init(1100, 1100));
    window.initText(@import("zon/font.zon"), text, 24);

    vertexBuffer = window.alloc(camera.Vertex, 5000);
    camera.frameStats(true);
    camera.init(vertexBuffer);

    far = .init("assets/image/Stars-B.png", 20);
    near = .init("assets/image/Stars-A.png", 30);
    zhu.audio.playMusic("assets/music/06_Battle_in_Space_Intro.ogg");
    player.init();
    enemy.init();
    end.init();
}

pub fn restart() void {
    currentScene = .game;
    player.restart();
    enemy.restart();
    end.restart();
    zhu.audio.playMusic("assets/music/03_Racing_Through_Asteroids_Loop.ogg");
}

pub fn handleEvent(event: *const window.Event) void {
    if (currentScene == .end) end.handleEvent(event);
}

pub fn update(delta: f32) void {
    if (!isTyping) {
        if (window.isKeyRelease(.H)) isHelp = !isHelp;
        if (window.isKeyRelease(.X)) isDebug = !isDebug;

        if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
            return window.toggleFullScreen();
        }
    }

    // 更新背景
    far.update(delta);
    near.update(delta);

    if (currentScene == .title) {
        title.update(delta);
    } else if (currentScene == .end) {
        end.update(delta);
    } else {
        if (window.isKeyRelease(.SPACE)) isPause = !isPause;
        if (isPause) return; // 暂停时不更新游戏

        // 更新玩家和敌人
        player.update(delta);
        enemy.update(delta);
    }
}

pub fn draw() void {
    camera.beginDraw(.{});
    defer camera.endDraw();
    window.keepAspectRatio();

    // 绘制背景
    // far.draw();
    // near.draw();

    if (currentScene == .title) {
        title.draw();
    } else if (currentScene == .end) {
        end.draw();
    } else {
        enemy.draw();
        player.draw();
    }
    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawTextColor(text, .init(10, 5), .green);
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\平滑：{d:.2}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
        \\相机：{d:.2}，{d:.2}
    ;

    const stats = camera.queryFrameStats();
    const text = zhu.format(&buffer, format, .{
        @tagName(camera.queryBackend()),
        window.frameRate,
        window.currentSmoothTime * 1000,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        camera.position.x,
        camera.position.y,
    });

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawTextColor(text, .init(10, 55), .green);
}

pub fn deinit() void {
    enemy.deinit();
    player.deinit();
    end.deinit();
    window.free(vertexBuffer);
}
