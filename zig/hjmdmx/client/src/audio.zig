const std = @import("std");
const sk = @import("sokol");
const cache = @import("cache.zig");
const c = @import("c.zig");

pub fn init(soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .stream_cb = callback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = soundBuffer;
}

pub fn deinit() void {
    stopMusic();
    for (sounds) |*sound| sound.valid = false;
    sk.audio.shutdown();
}

const Music = struct {
    source: *c.stbAudio.Audio,
    paused: bool = false,
    loop: bool = true,
};

var music: ?Music = null;

pub fn playMusic(path: [:0]const u8) void {
    doPlayMusic(path, true);
}

pub fn playMusicOnce(path: [:0]const u8) void {
    doPlayMusic(path, false);
}

fn doPlayMusic(path: [:0]const u8, loop: bool) void {
    stopMusic();

    const audio = c.stbAudio.load(path) catch unreachable;
    const info = c.stbAudio.getInfo(audio);
    const args = .{ info.sample_rate, info.channels, path };
    std.log.info("music sampleRate: {}, channels: {d}, path: {s}", args);

    music = .{ .source = audio, .loop = loop };
}

pub fn pauseMusic() void {
    if (music) |*value| value.paused = true;
}

pub fn resumeMusic() void {
    if (music) |*value| value.paused = false;
}

pub fn stopMusic() void {
    if (music) |*value| {
        c.stbAudio.unload(value.source);
        music = null;
    }
}

var sounds: []Sound = &.{};

pub const Sound = struct {
    source: []f32,
    valid: bool = true,
    loop: bool = true,
    index: usize = 0,
    sampleRate: u16 = 0,
    channels: u8 = 0,
};
pub const SoundIndex = usize;

pub fn playSound(path: [:0]const u8) void {
    _ = doPlaySound(path, false);
}

pub fn playSoundLoop(path: [:0]const u8) SoundIndex {
    return doPlaySound(path, true);
}

pub fn stopSound(sound: SoundIndex) void {
    sounds[sound].valid = false;
}

fn doPlaySound(path: [:0]const u8, loop: bool) SoundIndex {
    var sound = cache.Sound.load(path);
    sound.loop = loop;

    return addItem(sounds, sound);
}

fn addItem(slice: anytype, item: anytype) usize {
    for (slice, 0..) |*value, index| {
        if (!value.valid) {
            value.* = item;
            return index;
        }
    }
    std.debug.panic("too many items: {any}", .{item});
}

fn callback(b: [*c]f32, frames: i32, channels: i32) callconv(.C) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    @memset(buffer, 0);
    {
        if (music) |m| blk: {
            if (m.paused) break :blk;
            const count = c.stbAudio.fillSamples(m.source, buffer, channels);
            if (count == 0) {
                if (m.loop) c.stbAudio.reset(m.source) else music = null;
            }
        }
    }

    for (sounds) |*sound| {
        if (!sound.valid) continue;
        var len = mixSamples(buffer, sound);
        while (len < buffer.len and sound.valid) {
            len += mixSamples(buffer[len..], sound);
        }
    }
}

fn mixSamples(buffer: []f32, sound: *Sound) usize {
    const len = if (sound.channels == 1)
        mixMonoSamples(buffer, sound)
    else if (sound.channels == 2)
        mixStereoSamples(buffer, sound)
    else
        std.debug.panic("unsupported channels: {d}", .{sound.channels});

    if (sound.index == sound.source.len) {
        if (sound.loop) sound.index = 0 else sound.valid = false;
    }

    return len;
}

fn mixStereoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len, srcBuffer.len);

    for (0..len) |index| dstBuffer[index] += srcBuffer[index];
    sound.index += len;
    return len;
}

fn mixMonoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len / 2, srcBuffer.len);

    for (0..len) |index| {
        dstBuffer[index * 2] += srcBuffer[index];
        dstBuffer[index * 2 + 1] += srcBuffer[index];
    }
    sound.index += len;
    return len * 2;
}
