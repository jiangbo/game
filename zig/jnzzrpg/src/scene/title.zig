const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const scene = @import("../scene.zig");
const camera = @import("../camera.zig");

var backgrounds: [3]gfx.Texture = undefined;
var currentBackground: u8 = 0;
var timer: window.Timer = .init(5);
var logo: gfx.Texture = undefined;

const Button = struct {
    position: gfx.Vector,
    normal: gfx.Texture,
    hover: gfx.Texture,
};

var menuButtons: [3]Button = undefined;
var currentButton: u8 = 0;

const Popup = struct {
    background: gfx.Texture,
    buttons: [2]Button = undefined,
    current: u8 = 0,

    pub fn shadow(self: *Popup) void {
        displayPopup = false;
        self.current = 0;
    }
};

var popup: Popup = undefined;
var displayPopup: bool = false;

pub fn init() void {
    backgrounds[0] = gfx.loadTexture("assets/T_bg1.png", .init(800, 600));
    backgrounds[1] = gfx.loadTexture("assets/T_bg2.png", .init(800, 600));
    backgrounds[2] = gfx.loadTexture("assets/T_bg3.png", .init(800, 600));

    logo = gfx.loadTexture("assets/T_logo.png", .init(274, 102));

    const size = gfx.Vector.init(142, 36);
    menuButtons[0] = .{
        .position = .init(325, 350),
        .normal = gfx.loadTexture("assets/T_start_1.png", size),
        .hover = gfx.loadTexture("assets/T_start_2.png", size),
    };

    menuButtons[1] = .{
        .position = .init(325, 400),
        .normal = gfx.loadTexture("assets/T_load_1.png", size),
        .hover = gfx.loadTexture("assets/T_load_2.png", size),
    };

    menuButtons[2] = .{
        .position = .init(325, 450),
        .normal = gfx.loadTexture("assets/T_exit_1.png", size),
        .hover = gfx.loadTexture("assets/T_exit_2.png", size),
    };

    const bg = gfx.loadTexture("assets/confirm_bg.png", .init(227, 155));
    popup = Popup{ .background = bg };
    popup.buttons[0] = .{
        .position = .init(325, 305),
        .normal = gfx.loadTexture("assets/confirm_yes_1.png", size),
        .hover = gfx.loadTexture("assets/confirm_yes_2.png", size),
    };
    popup.buttons[1] = .{
        .position = .init(325, 355),
        .normal = gfx.loadTexture("assets/confirm_no_1.png", size),
        .hover = gfx.loadTexture("assets/confirm_no_2.png", size),
    };
}

pub fn enter() void {
    currentButton = 0;
    window.playMusic("assets/2.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    if (timer.isFinishedAfterUpdate(delta)) {
        currentBackground += 1;
        currentBackground %= backgrounds.len;
        timer.reset();
    }

    if (displayPopup) return updatePopup(delta);

    var mousePress = false;
    if (mouseInButton(&menuButtons)) |index| {
        currentButton = index;
        if (window.isButtonRelease(.LEFT)) mousePress = true;
    }

    if (window.isAnyKeyRelease(&.{ .W, .UP })) currentButton -|= 1;
    if (window.isAnyKeyRelease(&.{ .S, .DOWN })) currentButton += 1;
    currentButton = @min(currentButton, menuButtons.len - 1);

    if (window.isAnyKeyRelease(&.{ .ENTER, .SPACE }) or mousePress) {
        switch (currentButton) {
            0 => scene.changeScene(.world),
            1 => std.log.info("load game", .{}),
            2 => displayPopup = true,
            else => unreachable,
        }
    }
}

fn updatePopup(_: f32) void {
    var mousePress = false;
    if (mouseInButton(&popup.buttons)) |index| {
        popup.current = index;
        if (window.isButtonRelease(.LEFT)) mousePress = true;
    }

    if (window.isAnyKeyRelease(&.{ .W, .UP })) popup.current -|= 1;
    if (window.isAnyKeyRelease(&.{ .S, .DOWN })) popup.current += 1;
    popup.current = @min(popup.current, popup.buttons.len - 1);

    if (window.isAnyKeyRelease(&.{ .ENTER, .SPACE }) or mousePress) {
        switch (popup.current) {
            0 => window.exit(),
            1 => popup.shadow(),
            else => unreachable,
        }
    }
}

fn mouseInButton(buttons: []const Button) ?u8 {
    const size = buttons[0].normal.size();

    for (buttons, 0..) |button, index| {
        const area = gfx.Rectangle.init(button.position, size);
        if (area.contains(window.mousePosition))
            return @intCast(index);
    }
    return null;
}

pub fn render() void {
    camera.draw(backgrounds[currentBackground], .zero);
    camera.draw(logo, .init(260, 80));

    if (displayPopup) {
        camera.draw(popup.background, .init(283, 250));
        renderButtons(&popup.buttons, popup.current);
    } else {
        renderButtons(&menuButtons, currentButton);
    }
}

fn renderButtons(buttons: []Button, current: u8) void {
    for (buttons, 0..) |button, index| {
        if (current == index) {
            camera.draw(button.hover, button.position);
        } else {
            camera.draw(button.normal, button.position);
        }
    }
}
