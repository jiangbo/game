const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const Clock = @import("resource/Clock.zig");
const Speed = @import("resource/Speed.zig");
const World = ecs.World;

pub const Summary = struct { day: u32 = 0, timestamp: i64 = 0 };

pub const Slot = union(enum) { empty, valid: Summary };

pub const Config = struct {
    speed: f32 = 1,
    music: f32 = 1,
    sound: f32 = 1,
};

pub const Player = struct {
    map: component.map.Id = .town,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
};

pub const Inventory = struct {
    activeHotbar: usize = 0,
    activePage: usize = 0,
    slots: []const component.item.Stack = &.{},
    hotbar: []const ?usize = &.{},
};

pub const Object = union(enum) {
    gone,
    crop: component.farm.Crop,
    chest: component.item.Chest,
    product: component.item.Health,
};

pub const Tile = struct {
    index: u32 = 0,
    ground: ?component.farm.Ground = null,
    object: ?Object = null,
};

pub const Map = struct {
    day: u32 = 0,
    tiles: []Tile = &.{},
};

pub const MapRecord = struct {
    maps: std.EnumArray(component.map.Id, Map) = .initFill(.{}),

    pub fn deinit(self: MapRecord, gpa: zhu.Allocator) void {
        for (std.enums.values(component.map.Id)) |id| {
            gpa.free(self.maps.get(id).tiles);
        }
    }
};

pub const Record = struct {
    timestamp: i64 = 0,
    clock: Clock = .{},
    player: Player = .{},
    inventory: Inventory = .{},
    maps: MapRecord = .{},
};

var config: Config = .{};
pub var slots: [10]Slot = @splat(.empty);

pub fn init(world: *World) Config {
    config = load(Config, "config.json", .{});
    slots = load(@TypeOf(slots), "saves/slots.json", @splat(.empty));
    sync(world, config);
    return config;
}

pub fn update(world: *World, cfg: Config) void {
    if (std.meta.eql(config, cfg)) return;

    sync(world, cfg);
    zhu.extend.storage.writeJson("config.json", cfg) catch |err| {
        std.log.err("save config failed: {}", .{err});
        return;
    };
    config = cfg;
}

fn sync(world: *World, cfg: Config) void {
    world.getResourcePtr(Speed).?.value = cfg.speed;
    zhu.audio.musicVolume.store(cfg.music, .release);
    zhu.audio.soundVolume.store(cfg.sound, .release);
}

pub fn read(slot: u8) !std.json.Parsed(Record) {
    var buffer: [32]u8 = undefined;
    const path = zhu.formatZ(&buffer, "saves/slot{d}.json", .{slot});
    const record = try zhu.extend.storage.readJson(Record, path);
    std.log.info("game loaded: {s}", .{path});
    return record;
}

pub fn write(slot: u8, record: Record) !void {
    var buffer: [32]u8 = undefined;
    const path = zhu.formatZ(&buffer, "saves/slot{d}.json", .{slot});

    try zhu.extend.storage.writeJson(path, record);

    slots[slot] = .{ .valid = .{
        .day = record.clock.day,
        .timestamp = record.timestamp,
    } };
    try zhu.extend.storage.writeJson("saves/slots.json", slots);
    std.log.info("game saved: {s}", .{path});
}

fn load(T: type, path: [:0]const u8, default: T) T {
    var loaded = zhu.extend.storage.readJson(T, path) catch |err| switch (err) {
        error.FileNotFound => return default,
        else => std.debug.panic("load {s} failed: {}", .{ path, err }),
    };
    defer loaded.deinit();

    return loaded.value;
}
