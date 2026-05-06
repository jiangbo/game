const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const Button = struct {
    offset: zhu.Vector2,
    size: zhu.Vector2,
    normal: zhu.graphics.ImageId,
    hover: zhu.graphics.ImageId,
    pressed: zhu.graphics.ImageId,
    event: u8,
};

const Menu = struct {
    position: zhu.Vector2,
    offset: zhu.Vector2,
    buttons: []const Button,
};

const ButtonState = enum { normal, hover, pressed };

const menus: []const Menu = @import("zon/menu.zon");
pub var menuIndex: u8 = 0;
var buttonIndex: ?usize = null;
var buttonState: ButtonState = .normal;

pub fn update() ?u8 {
    const menu = menus[menuIndex];
    const mousePos = zhu.window.mousePosition;
    const position = menu.position;

    for (menu.buttons, 0..menu.buttons.len) |button, i| {
        const index: f32 = @floatFromInt(i);
        const pos = position.add(menu.offset.scale(index));
        const buttonPos = pos.add(button.offset);
        const buttonArea = zhu.Rect.init(buttonPos, button.size);

        const hover = buttonArea.contains(mousePos);
        const press = zhu.window.isMouseDown(.LEFT);
        if (hover) {
            if (buttonIndex == null) {
                // 刚刚进入悬停状态，播放音效
                zhu.audio.playSound("assets/audio/button_hover.ogg");
            }
            if (zhu.window.isMouseReleased(.LEFT)) {
                zhu.audio.playSound("assets/audio/button_click.ogg");
                return button.event;
            }
            buttonIndex = i;
            buttonState = if (press) .pressed else .hover;
            break;
        } else if (!press) {
            buttonState = .normal;
        }
    } else if (buttonState != .pressed) buttonIndex = null;

    return null;
}

pub fn draw() void {
    const menu = menus[menuIndex];
    const position = menu.position;
    for (menu.buttons, 0..menu.buttons.len) |button, i| {
        const index: f32 = @floatFromInt(i);
        const pos = position.add(menu.offset.scale(index));

        if (i == buttonIndex and buttonState != .normal) {
            if (buttonState == .pressed) {
                batch.drawImageId(button.pressed, pos, .{});
            } else if (buttonState == .hover) {
                batch.drawImageId(button.hover, pos, .{});
            }
        } else {
            batch.drawImageId(button.normal, pos, .{});
        }
    }
}
