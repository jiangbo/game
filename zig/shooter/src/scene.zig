const zhu = @import("zhu");

const player = @import("player.zig");
const enemy = @import("enemy.zig");
const title = @import("title.zig");
const end = @import("end.zig");

const Background = struct {
    image: zhu.Image,
    size: zhu.Vector2,
    offset: f32,
    speed: f32,

    fn init(path: [:0]const u8, speed: f32) Background {
        const image = zhu.assets.loadImage(path, .xy(1000, 1000));
        return .{
            .image = image,
            .size = image.size.scale(0.5),
            .offset = 0,
            .speed = speed,
        };
    }

    fn update(self: *Background, delta: f32) void {
        self.offset += self.speed * delta;
        if (self.offset > 0) self.offset -= self.size.y;
    }

    fn draw(self: *const Background) void {
        var y = self.offset;
        // 填满 Y 轴。
        while (y < zhu.window.size.y) : (y += self.size.y) {
            var x: f32 = 0;
            // 填满 X 轴。
            while (x < zhu.window.size.x) : (x += self.size.x) {
                zhu.batch.drawImage(self.image, .xy(x, y), .{
                    .size = self.size,
                });
            }
        }
    }
};

var isHelp = false;
var isDebug = false;
var isPause = false;

var far: Background = undefined; // 远景
var near: Background = undefined; // 近景

const SceneType = enum { title, game, end };
pub var currentScene: SceneType = .title;
pub var isTyping: bool = false;

pub fn init(allocator: zhu.Allocator) void {
    zhu.assets.loadAtlas(@import("zon/atlas.zon"));

    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const size = zhu.batch.circleImage.size;
    const rect = zhu.Rect.init(.zero, size).centerScale(0.25);
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(rect);

    zhu.text.init(@import("zon/font.zon"));
    zhu.text.changeFontSize(24);

    far = .init("Stars-B.png", 20);
    near = .init("Stars-A.png", 30);
    zhu.audio.playMusic("music/06_Battle_in_Space_Intro.ogg");
    player.init(allocator.raw);
    enemy.init(allocator.raw);
    end.init(allocator.raw);
}

pub fn restart() void {
    currentScene = .game;
    player.restart();
    enemy.restart();
    end.restart();
    zhu.audio.playMusic("music/03_Racing_Through_Asteroids_Loop.ogg");
}

pub fn handleEvent(event: *const zhu.window.Event) void {
    if (currentScene == .end) end.handleEvent(event);
}

pub fn update(delta: f32) void {
    if (!isTyping) {
        if (zhu.key.released(.H)) isHelp = !isHelp;
        if (zhu.key.released(.X)) isDebug = !isDebug;

        if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
            return zhu.window.toggleFullScreen();
        }
    }

    far.update(delta);
    near.update(delta);

    if (currentScene == .title) {
        title.update(delta);
    } else if (currentScene == .end) {
        end.update(delta);
    } else {
        if (zhu.key.released(.SPACE)) isPause = !isPause;
        if (isPause) return;

        player.update(delta);
        enemy.update(delta);
    }
}

pub fn draw() void {
    far.draw();
    near.draw();

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
    const help =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;
    zhu.text.draw(help, .xy(10, 5), .{ .color = .green });
}

fn drawDebugInfo() void {
    zhu.debug.draw(&.{});
}

pub fn deinit() void {
    enemy.deinit();
    player.deinit();
    end.deinit();
}
