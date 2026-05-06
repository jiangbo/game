const std = @import("std");
const zhu = @import("zhu");

const Entity = zhu.ecs.Entity; // 实体

pub const Position = zhu.Vector2; // 位置
pub const Sprite = struct { // 精灵
    image: zhu.graphics.Image,
    offset: zhu.Vector2,
    size: ?zhu.Vector2 = null,
    flip: bool = false,
};

pub const Timer = struct { // 计时器
    remaining: f32,
    entity: zhu.ecs.Entity,
    type: enum { attack },
};

pub const Path = struct { // 路径
    point: zhu.Vector2, // 路径点位置
    next: u8 = 0, // 终点没有下一个路径点
    next2: u8 = 0, // 可选的第二条分支路径
};
pub const Enemy = struct { target: Path, speed: f32 }; // 敌人
pub const EnemyEnum = enum { slime, wolf, goblin, darkWitch }; // 敌人类型
pub const Player = struct { cost: f32 }; // 玩家
pub const PlayerEnum = enum { warrior, archer, lancer, witch }; // 玩家类型
pub const SkillEnum = enum { shield, speedUp, rest, powerUp }; // 技能类型
pub const EffectEnum = enum { heal, active, ready, levelUp }; // 特效类型
pub const StateEnum = enum { idle, walk, damage, attack, ranged };
pub const ActionEnum = enum(u32) { none = 0, hit = 1, emit = 2 };
pub const ProjectileEnum = enum { arrow, magic }; // 投射物类型

pub const Projectile = struct {
    start: zhu.Vector2, // 起始位置
    end: zhu.Vector2, // 终点位置
    previous: zhu.Vector2 = .zero, // 上一帧位置
    arc: f32, // 弧度
    time: f32 = 0, // 飞行时间
    totalTime: f32, // 总飞行时间
    owner: Entity, // 发出者
    target: Entity, // 命中目标
    damage: f32, // 发射瞬间锁定的伤害
    offset: zhu.Vector2, // 绘制偏移
    rotation: f32 = 0, // 旋转角度
};

pub const Dead = struct {}; // 死亡标签
pub const DeadOnFinish = struct {}; // 动画结束后标记死亡
pub const ShowRange = struct {}; // 显示攻击范围标签
pub const Name = struct { value: [:0]const u8 }; // 名称组件
pub const ClassName = struct { value: [:0]const u8 }; // 职业名称组件

///
/// 技能相关组件
///
pub const skill = struct {
    pub const CostRecovery = struct { rate: f32 }; // COST 恢复组件

    pub const Skill = struct { // 技能组件
        id: SkillEnum,
        name: [:0]const u8,
        description: [:0]const u8,
        passive: bool = false,
        coolDown: f32 = 0,
        duration: f32 = 0,
        displayEntity: ?Entity = null,
        buff: Stats = .{},
        costRecovery: f32 = 0,
    };

    pub const Timer = zhu.Timer; // 技能计时器
    pub const Ready = struct {}; // 技能准备完毕
    pub const Active = struct {}; // 技能激活中
    pub const Passive = struct {}; // 被动技能
    pub const Cast = struct {}; // 请求施放技能
    pub const Backup = struct { stats: Stats }; // 备份原始属性
    // 技能显示实体
    pub const Display = struct { owner: Entity, effect: EffectEnum };
};

///
/// 移动相关组件
///
pub const motion = struct {
    pub const Velocity = struct { v: zhu.Vector2 }; // 速度
    pub const FaceLeft = struct {}; // 面向左侧
    pub const Blocker = struct { max: u8, current: u8 = 0 }; // 阻挡者
    pub const BlockBy = struct { v: Entity }; // 被阻挡
};

///
/// 攻击相关组件
///
pub const attack = struct {
    pub const Target = struct { v: Entity }; // 攻击目标
    pub const Ready = struct {}; // 冷却完毕，可以攻击。
    pub const Lock = struct {}; // 攻击锁定
    pub const Healer = struct {}; // 治疗者
    pub const Injured = struct {}; // 受伤标签
    pub const Ranged = struct {}; // 远程攻击
    pub const Hit = struct {}; // 命中标签
    pub const Emit = struct {}; // 发出攻击标签
};

///
/// 属性
///
pub const Stats = struct {
    health: f32 = 1,
    maxHealth: f32 = 1,
    attack: f32 = 1,
    defense: f32 = 1,
    range: f32 = 1,
    interval: f32 = 1,
    level: f32 = 1,
    rarity: f32 = 1,
};

///
/// 动画
///
pub const Animation = zhu.graphics.Animation;
pub const animation = struct {
    pub const Finished = struct {};
    pub const Play = struct { index: u8, loop: bool = false };
};

///
/// 声音
///
pub const audio = struct {
    pub const Hit = struct { path: [:0]const u8 };
    pub const Emit = struct { path: [:0]const u8 };
};
