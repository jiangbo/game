const zhu = @import("zhu");
const ecs = zhu.ecs;

const com = @import("../component.zig");
const ctx = @import("../context.zig");
const spawn = @import("../spawn.zig");

const displayPositionOffset = zhu.Vector2.xy(0, -96);

pub fn update(reg: *ecs.Registry, delta: f32) void {
    updateCast(reg);
    updateTimer(reg, delta);
    updateCostRecovery(reg, delta);
    updateDisplay(reg);
}

/// 处理技能施放请求：备份原始属性，应用 buff 倍率，进入激活状态。
fn updateCast(reg: *ecs.Registry) void {
    var view = reg.view(.{ com.skill.Cast, com.skill.Ready });
    while (view.next()) |entity| {
        if (view.has(entity, com.skill.Passive)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);

        if (view.tryGetPtr(entity, com.Stats)) |stats| {
            const buff = skill.buff;
            inline for (@typeInfo(com.Stats).@"struct".fields) |field| {
                @field(stats, field.name) *= @field(buff, field.name);
            }
        }
        view.remove(entity, com.skill.Ready);
        view.add(entity, com.skill.Active{});
        view.add(entity, com.skill.Timer.init(skill.duration));
        // 盾御技能激活时切换防御姿态动画
        if (skill.id == .shield) {
            view.add(entity, com.animation.Play{
                .index = @intFromEnum(com.StateEnum.walk),
                .loop = true,
            });
        }
    }

    reg.clear(com.skill.Cast);
}

/// 迭代有 Timer 的技能实体，计时结束根据 Active 判断：
/// 有 Active → 持续结束，恢复属性，切回冷却；无 Active → 冷却结束，标记 Ready。
fn updateTimer(reg: *ecs.Registry, delta: f32) void {
    var view = reg.view(.{com.skill.Timer});
    while (view.next()) |entity| {
        const timer = view.getPtr(entity, com.skill.Timer);
        if (!timer.isFinishedOnceUpdate(delta)) continue;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (view.has(entity, com.skill.Active)) {
            // 持续结束：按倍率还原属性，切回冷却计时
            if (view.tryGetPtr(entity, com.Stats)) |stats| {
                const buff = skill.buff;
                inline for (@typeInfo(com.Stats).@"struct".fields) |field| {
                    @field(stats, field.name) /= @field(buff, field.name);
                }
            }
            if (skill.id == .shield) {
                view.add(entity, com.animation.Play{
                    .index = @intFromEnum(com.StateEnum.idle),
                    .loop = true,
                });
            }
            view.remove(entity, com.skill.Active);
            timer.* = .init(skill.coolDown);
        } else {
            // 冷却结束：标记 Ready，移除 Timer
            view.add(entity, com.skill.Ready{});
            view.remove(entity, com.skill.Timer);
        }
    }
}

fn updateCostRecovery(reg: *ecs.Registry, delta: f32) void {
    var view = reg.view(.{ com.skill.CostRecovery, com.skill.Active });
    while (view.next()) |entity| {
        const recovery = view.get(entity, com.skill.CostRecovery);
        ctx.cost += recovery.rate * delta;
    }
}

fn updateDisplay(reg: *ecs.Registry) void {
    updateExistingDisplay(reg);
    createMissingDisplay(reg);
}

/// 检查已有特效实体：owner 死亡或状态不匹配时标记 Dead，
/// 状态匹配时更新位置跟随 owner。
fn updateExistingDisplay(reg: *ecs.Registry) void {
    var view = reg.reverseView(.{ com.skill.Display, com.Position, com.Sprite });
    while (view.next()) |entity| {
        const display = view.getPtr(entity, com.skill.Display);
        const displayEntity = view.toEntity(entity);
        const owner = display.owner;

        if (!reg.validEntity(owner)) {
            reg.add(displayEntity, com.Dead{});
            continue;
        }

        var state: ?com.EffectEnum = null;
        if (reg.has(owner, com.skill.Active)) state = .active;
        if (reg.has(owner, com.skill.Ready)) state = .ready;

        if (state == null or display.effect != state.?) {
            reg.getPtr(owner, com.skill.Skill).displayEntity = null;
            reg.add(displayEntity, com.Dead{});
            continue;
        }

        view.getPtr(entity, com.Position).* = displayPosition(reg, owner);
    }
}

/// 为有可显示状态（Ready/Active）但缺少特效的技能创建特效实体。
fn createMissingDisplay(reg: *ecs.Registry) void {
    var view = reg.view(.{ com.skill.Skill, com.Position });
    while (view.next()) |entity| {
        var state: ?com.EffectEnum = null;
        if (view.has(entity, com.skill.Active)) state = .active;
        if (view.has(entity, com.skill.Ready)) state = .ready;

        const skill = view.getPtr(entity, com.skill.Skill);
        if (reg.validEntity(skill.displayEntity)) continue;

        const displayEntity = spawn.effect(reg, state orelse continue);
        const owner = view.toEntity(entity);
        reg.add(displayEntity, displayPosition(reg, owner));
        reg.getPtr(displayEntity, com.Animation).loop = true;
        skill.displayEntity = displayEntity;
        reg.add(displayEntity, com.skill.Display{
            .owner = owner,
            .effect = state.?,
        });
    }
}

fn displayPosition(reg: *ecs.Registry, owner: ecs.Entity) com.Position {
    const position = reg.get(owner, com.Position);
    return position.add(displayPositionOffset);
}
