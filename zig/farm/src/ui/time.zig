const zhu = @import("zhu");
const ecs = @import("ecs");

const Clock = @import("../resource/Clock.zig");

const World = ecs.World;

const uiScale: f32 = 2.0;
const clockSize = zhu.Vector2.xy(32, 32);

var extras: zhu.Image = undefined;
var clockFace: zhu.Image = undefined;
var clockHand: zhu.Image = undefined;
var panelImage: zhu.NineImage = undefined;
var labelImage: zhu.NineImage = undefined;

pub fn init() void {
    extras = zhu.getImage("farm-rpg/UI/Clock/Extras.png").?;
    clockFace = zhu.getImage("farm-rpg/UI/Clock/Clock.png").?
        .sub(.init(.zero, clockSize));
    clockHand = zhu.getImage("farm-rpg/UI/Clock/clock hand.png").?;

    var image = extras.sub(.init(.xy(66, 65), .xy(59, 28)));
    panelImage = .{
        .image = image,
        .patch = .{ .min = .xy(1, 3), .max = .xy(1, 1) },
    };

    image = extras.sub(.init(.xy(71, 99), .xy(33, 10)));
    labelImage = .{
        .image = image,
        .patch = .{ .min = .xy(1, 1), .max = .xy(1, 1) },
    };
}

pub fn draw(world: *World) void {
    const clock = world.getPtr(world.entity, Clock).?;

    zhu.camera.push(.windowScale(.xy(10, 10), .square(uiScale)));
    defer zhu.camera.pop();

    zhu.batch.drawNine(panelImage, panelImage.rectAt(.xy(20, 0)));
    zhu.batch.drawImage(clockFace, .xy(0, -2), .{});

    const index: u8 = ((clock.hour + 13) % 24) / 3;
    const handX = @as(f32, @floatFromInt(index)) * clockSize.x;
    const image = clockHand.sub(.init(.xy(handX, 0), clockSize));
    zhu.batch.drawImage(image, .xy(0, -2), .{});

    const size = labelImage.image.size;
    const rect = zhu.Rect.init(.xy(34, 3), size);
    const timeRect = rect.move(.xy(0, size.y + 2));
    zhu.batch.drawNine(labelImage, rect);
    zhu.batch.drawNine(labelImage, timeRect);

    var buffer: [16]u8 = undefined;
    var option: zhu.text.Option = .{
        .scale = .square(1.0 / uiScale),
        .anchor = .center,
    };
    const dayText = zhu.format(&buffer, "Day {d}", .{clock.day});
    zhu.text.draw(dayText, rect.center(), option);

    const args = .{ clock.hour, @as(u8, @intFromFloat(clock.minute)) };
    const timeText = zhu.format(&buffer, "{d:0>2}:{d:0>2}", args);
    option.offset = .xy(0, 1 / uiScale);
    zhu.text.draw(timeText, timeRect.center(), option);
}
