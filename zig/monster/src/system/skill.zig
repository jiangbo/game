const zhu = @import("zhu");
const ecs = @import("ecs");

const com = @import("../component.zig");
const ctx = @import("../context.zig");
const spawn = @import("../spawn.zig");

const displayPositionOffset = zhu.Vector2.xy(0, -96);

pub fn update(reg: *ecs.World, delta: f32) void {
    updateCast(reg);
    updateTimer(reg, delta);
    updateCostRecovery(reg, delta);
    updateDisplay(reg);
}

/// 处理技能施放请求：备份原始属性，应用 buff 倍率，进入激活状态。
fn updateCast(reg: *ecs.World) void {
    var view = reg.query(.{ com.skill.Cast, com.skill.Ready }).reverse();
    while (view.next()) |entity| {
        if (reg.has(entity, com.skill.Passive)) continue;

        const skill = reg.getPtr(entity, com.skill.Skill).?;

        if (reg.getPtr(entity, com.Stats)) |stats| {
            const buff = skill.buff;
            inline for (@typeInfo(com.Stats).@"struct".field_names) |field| {
                @field(stats, field) *= @field(buff, field);
            }
        }
        reg.remove(entity, com.skill.Ready);
        reg.add(entity, com.skill.Active{});
        reg.add(entity, com.skill.Timer.init(skill.duration));
        // 盾御技能激活时切换防御姿态动画
        if (skill.id == .shield) {
            reg.add(entity, com.animation.Play{
                .index = .walk,
                .loop = true,
            });
        }
    }

    reg.clear(com.skill.Cast);
}

/// 迭代有 Timer 的技能实体，计时结束根据 Active 判断：
/// 有 Active → 持续结束，恢复属性，切回冷却；无 Active → 冷却结束，标记 Ready。
fn updateTimer(reg: *ecs.World, delta: f32) void {
    var view = reg.query(.{com.skill.Timer}).reverse();
    while (view.next()) |entity| {
        const timer = reg.getPtr(entity, com.skill.Timer).?;
        if (!timer.updateFinished(delta)) continue;

        const skill = reg.getPtr(entity, com.skill.Skill).?;
        if (reg.has(entity, com.skill.Active)) {
            // 持续结束：按倍率还原属性，切回冷却计时
            if (reg.getPtr(entity, com.Stats)) |stats| {
                const buff = skill.buff;
                inline for (@typeInfo(com.Stats).@"struct".field_names) |field| {
                    @field(stats, field) /= @field(buff, field);
                }
            }
            if (skill.id == .shield) {
                reg.add(entity, com.animation.Play{
                    .index = .idle,
                    .loop = true,
                });
            }
            reg.remove(entity, com.skill.Active);
            timer.* = .init(skill.coolDown);
        } else {
            // 冷却结束：标记 Ready，移除 Timer
            reg.add(entity, com.skill.Ready{});
            reg.remove(entity, com.skill.Timer);
        }
    }
}

fn updateCostRecovery(reg: *ecs.World, delta: f32) void {
    var view = reg.query(.{ com.skill.CostRecovery, com.skill.Active }).reverse();
    while (view.next()) |entity| {
        const recovery = reg.get(entity, com.skill.CostRecovery).?;
        ctx.cost += recovery.rate * delta;
    }
}

fn updateDisplay(reg: *ecs.World) void {
    updateExistingDisplay(reg);
    createMissingDisplay(reg);
}

/// 状态改变时移除旧特效；拥有者销毁前也会调用 removeDisplay。
fn updateExistingDisplay(reg: *ecs.World) void {
    var view = reg.query(.{ com.skill.Display, com.Position, com.Sprite }).reverse();
    while (view.next()) |entity| {
        const display = reg.getPtr(entity, com.skill.Display).?;
        const owner = display.owner;

        var state: ?com.EffectEnum = null;
        if (reg.has(owner, com.skill.Active)) state = .active;
        if (reg.has(owner, com.skill.Ready)) state = .ready;

        if (state == null or display.effect != state.?) {
            removeDisplay(reg, owner);
            continue;
        }

        reg.getPtr(entity, com.Position).?.* = displayPosition(reg, owner);
    }
}

/// 为有可显示状态（Ready/Active）但缺少特效的技能创建特效实体。
fn createMissingDisplay(reg: *ecs.World) void {
    var view = reg.query(.{com.skill.Skill}).reverse();
    while (view.next()) |entity| {
        var state: ?com.EffectEnum = null;
        if (reg.has(entity, com.skill.Active)) state = .active;
        if (reg.has(entity, com.skill.Ready)) state = .ready;

        const skill = reg.getPtr(entity, com.skill.Skill).?;
        if (skill.displayEntity != null) continue;

        const displayEntity = spawn.effect(reg, state orelse continue);
        const owner = entity;
        reg.add(displayEntity, displayPosition(reg, owner));
        reg.getPtr(displayEntity, com.Animation).?.source.loop = true;
        skill.displayEntity = displayEntity;
        reg.add(displayEntity, com.skill.Display{
            .owner = owner,
            .effect = state.?,
        });
    }
}

fn displayPosition(reg: *ecs.World, owner: ecs.Entity) com.Position {
    const position = reg.get(owner, com.Position).?;
    return position.add(displayPositionOffset);
}

// 特效只由技能状态切换或拥有者销毁时移除，编号不会留下悬空引用。
pub fn removeDisplay(reg: *ecs.World, owner: ecs.Entity) void {
    const skill = reg.getPtr(owner, com.skill.Skill) orelse return;
    const entity = skill.displayEntity orelse return;
    skill.displayEntity = null;
    reg.destroyEntity(entity);
}
