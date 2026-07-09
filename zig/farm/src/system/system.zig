const zhu = @import("zhu");
const ecs = @import("ecs");

pub const animation = @import("animation.zig");
pub const chest = @import("chest.zig");
pub const control = @import("control.zig");
pub const dialog = @import("dialog.zig");
pub const farm = @import("farm.zig");
pub const interact = @import("interact.zig");
pub const life = @import("life.zig");
pub const light = @import("light.zig");
pub const movement = @import("movement.zig");
pub const pickup = @import("pickup.zig");
pub const render = @import("render.zig");
pub const rest = @import("rest.zig");
pub const sound = @import("sound.zig");
pub const time = @import("time.zig");
pub const transition = @import("transition.zig");
pub const wander = @import("wander.zig");

pub fn init() void {
    // 有独立资源或初始状态的系统在进入首个场景前完成初始化。
    dialog.init();
    light.init();
}

pub fn update(world: *ecs.World, delta: f32) void {
    // 时间先推进，地图跨天逻辑和灯光都依赖本帧最新时间事件。
    time.update(world, delta);
    light.update(world);

    // 控制系统先写入意图，移动系统统一结算位置和碰撞。
    control.update(world);
    life.update(world, delta);
    wander.update(world, delta);
    movement.update(world, delta);

    // 控制系统可能生成拾取物，所以拾取放在控制之后。
    pickup.update(world, delta);

    // 按 F 的处理、相机跟随、动画和排序都读取本帧已结算的位置。
    interact.update(world);
    dialog.update(world);
    chest.update(world);
    rest.update(world);
    animation.update(world, delta);
    farm.update(world);
    render.update(world);

    // 本帧世界结算完后记录下一帧是否需要切图。
    transition.update(world);

    // 音效最后播放，统一消费本帧前面系统发出的 SoundPlay 事件。
    sound.update(world);
}
