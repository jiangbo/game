const std = @import("std");
const zhu = @import("zhu");

const Vector2 = zhu.Vector2;
pub const Position = zhu.Vector2;

pub const motion = struct {
    pub const Velocity = struct { value: Vector2 = .zero };

    pub const Shape = zhu.math.Shape;
    pub const Blocking = struct {};
};

pub const render = struct {
    pub const Sprite = struct {
        image: zhu.graphics.Image,
        offset: zhu.Vector2 = .zero,
        size: ?zhu.Vector2 = null,
        flip: bool = false,
    };

    pub const Layer = enum(i16) {
        ground = 0,
        crop = 10,
        actor = 20,
    };

    pub const Render = struct {
        layer: Layer = .actor,
        depth: f32 = 0,
        color: zhu.Color = .white,
    };

    pub const YSort = struct {};
    pub const Hidden = struct {};
};

pub const map = struct {
    pub const Id = enum { school, town, exterior, interior };
    pub const StartOffset = enum { none, left, right, top, bottom };

    pub const Trigger = struct {
        rect: zhu.Rect,
        selfId: i32,
        targetId: i32,
        targetMap: Id,
        startOffset: StartOffset,
    };

    pub const Transition = struct { target: Id, targetId: i32 };

    pub const Rest = struct {};
    pub const SolidRange = struct { start: usize, count: usize };
    pub const Hit = struct {};
};

pub const actor = struct {
    pub const AnimalEnum = enum { cow, sheep };

    pub const Action = enum {
        idle, // 待机
        walk, // 行走
        sleep, // 睡眠
        eat, // 进食
        hoe, // 锄地
        watering, // 浇水
        planting, // 播种
        sickle, // 镰刀
        axe, // 斧头
        pickaxe, // 镐头
    };

    pub const Animation = zhu.graphics.Animation;

    pub const Player = struct {};
    pub const Npc = struct {};
    pub const Interact = struct {};
    pub const Animal = AnimalEnum;
    pub const Facing = enum { down, up, left, right };
    pub const Actor = struct {
        action: Action = .idle,
        facing: Facing = .down,
        rows: [4]i8 = .{ 1, 2, -3, 3 },
    };
    pub const Busy = struct {};

    // 动画到达可结算帧时挂上，farm 系统消费后立即移除。
    pub const UseFrame = struct {};

    // 点击瞬间锁定的使用意图，避免关键帧时再读取变化后的快捷栏。
    pub const WantUse = struct { item: item.ItemEnum, target: Vector2 };

    pub const Wander = struct {
        home: zhu.Vector2 = .zero,
        radius: f32 = 0,
        speed: f32 = 0,
        target: zhu.Vector2 = .zero,
        waitTimer: f32 = 0,
        moving: bool = false,
        minWait: f32 = 0.6,
        maxWait: f32 = 1.8,
        lastDistance2: f32 = 0,
        stuckTimer: f32 = 0,
        stuckReset: f32 = 1.0,
    };

    // 生活状态：挂上后会按时间在普通、睡觉、进食之间切换。
    pub const Life = struct {
        pub const State = enum { normal, sleep, eat };
        // 进食间隔上限，实际等待在一半到该值之间随机。
        pub const eatInterval: f32 = 8.0;
        // 单次进食时长上限，实际时长在一半到该值之间随机。
        pub const eatDuration: f32 = 2.0;

        state: State = .normal,
        // normal 时表示进食冷却，eat 时表示剩余进食时间。
        timer: f32 = 0,
    };

    // 对话组件：挂载到可交互的 NPC 上
    // 同时用作 Identity 标记当前正在对话的实体
    pub const Dialog = struct {
        lines: []const []const u8 = &.{}, // 当前角色的对话内容
        index: usize = 0, // 当前显示到第几行

        pub const interactDist: f32 = 64.0; // 触发对话的最大距离
        pub const closeDist: f32 = 96.0; // 自动关闭对话的距离
    };
};

pub const farm = struct {
    pub const Ground = enum { dry, wet };
    pub const GrowthEnum = enum { seed, sprout, growing, mature };
    pub const CropEnum = enum { strawberry, potato };

    pub const Crop = struct {
        stage: GrowthEnum = .seed,
        kind: CropEnum = .strawberry,
        timer: f32 = 0,
        next: f32 = 0,
        watered: bool = false,
    };
};

pub const ui = struct {
    pub const Target = struct {
        position: zhu.Vector2 = .zero,
        color: zhu.Color = .rgba(0, 1, 0, 0.2),
        active: bool = false,
    };
};

pub const item = struct {
    pub const ItemEnum = enum {
        hoe,
        water,
        pickaxe,
        axe,
        sickle,
        strawberrySeed,
        potatoSeed,
        strawberry,
        potato,
        timber,
        stone,
    };

    pub const Stack = zhu.widget.StackT(ItemEnum);
    // Product 只表示动作完成后产出的物品，生命值单独放在 Health。
    pub const Product = struct { value: Stack };
    pub const Health = struct { value: u8 };
    pub const Hit = struct { target: ItemEnum };

    pub const Pickup = struct { item: ItemEnum, count: u32 = 1 };

    pub const PickupMotion = struct {
        start: zhu.Vector2 = .zero,
        target: zhu.Vector2 = .zero,
        timer: zhu.Timer = .init(0.22),
    };
    pub const Counts = std.EnumArray(ItemEnum, u32);

    // 宝箱：items 记录从地图对象属性读取到的奖励数量。
    pub const Chest = struct {
        opened: bool = false,
        items: Counts = .initFill(0),
    };
};

pub const time = struct {
    pub const Period = enum { dawn, day, dusk, night };
};

pub const light = struct {
    pub const Point = struct {
        radius: f32 = 96,
        offset: zhu.Vector2 = .zero,
        color: zhu.Color = .rgba(1.0, 0.72, 0.34, 1.0),
        intensity: f32 = 1.0,
    };

    pub const Spot = struct {
        radius: f32 = 128,
        direction: zhu.Vector2 = .xy(0, -1),
        color: zhu.Color = .rgba(1.0, 0.72, 0.34, 1.0),
        intensity: f32 = 1.0,
    };

    pub const Disabled = struct {};
    pub const Night = struct {};
    pub const Day = struct {};
    pub const Pending = struct {};
};

pub const sound = struct {
    pub const Id = enum {
        hoe,
        water,
        harvest,
        pickup,
        plant,
        axe,
        pickaxe,
        cow,
        sheep,
    };

    // 发声请求标记：音效系统播放后立即移除。
    pub const Emit = struct {};

    pub const Voice = struct {
        probability: f32,
        coolDown: f32,
        remaining: f32 = 0,
    };
};

// 事件类型：系统间通信的一次性消息
pub const event = struct {
    pub const Rest = struct { hours: u8 };
    pub const HourChanged = struct {};
    pub const DayChanged = struct { day: u32 };
    pub const PeriodChanged = struct {
        day: u32,
        hour: u8,
        period: time.Period,
    };

    pub const SoundPlay = struct { id: sound.Id };
};
