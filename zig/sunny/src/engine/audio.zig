const std = @import("std");
const sk = @import("sokol");
const assets = @import("assets.zig");
const stbAudio = @import("c.zig").stbAudio;

pub fn init(sampleRate: u32, soundBuffer: []Sound) void {
    sk.audio.setup(.{
        .num_channels = 2,
        .sample_rate = @intCast(sampleRate),
        .stream_cb = audioCallback,
        .logger = .{ .func = sk.log.func },
    });
    sounds = soundBuffer;
    for (sounds) |*sound| sound.state = .stopped;
}

pub fn deinit() void {
    stopMusic();
    for (sounds) |*sound| sound.state = .stopped;
    sk.audio.shutdown();
}

const AudioState = enum { init, playing, paused, stopped };
pub const Music = struct {
    source: *stbAudio.Audio = undefined,
    state: AudioState = .init,
    loop: bool = true,
};

pub var music: ?Music = null;
pub var musicVolume: f32 = 1.0;
pub var soundVolume: f32 = 1.0;
pub var paused: bool = false;

pub fn setVolume(volume: f32) void {
    musicVolume = volume;
    soundVolume = volume;
}

pub fn playMusic(path: [:0]const u8) void {
    music = assets.loadMusic(path, true).*;
}

pub fn playMusicOnce(path: [:0]const u8) void {
    music = assets.loadMusic(path, false).*;
}

pub fn pauseMusic() void {
    if (music) |*value| value.state = .paused;
}

pub fn resumeMusic() void {
    if (music) |*value| value.state = .playing;
}

pub fn stopMusic() void {
    if (music) |*value| value.state = .stopped;
}

pub var sounds: []Sound = &.{};

pub const Sound = struct {
    handle: SoundHandle,
    source: []f32 = &.{},
    loop: bool = true,
    index: usize = 0,
    channels: u8 = 0,
    state: AudioState = .init,
};
pub const SoundHandle = usize;

pub fn playSound(path: [:0]const u8) void {
    const sound = assets.loadSound(path, false).*;
    if (sound.state == .playing) sounds[allocSoundBuffer()] = sound;
}

pub fn playSoundLoop(path: [:0]const u8) SoundHandle {
    const sound = assets.loadSound(path, true).*;
    var index = sound.handle;
    if (sound.state == .playing) {
        index = allocSoundBuffer();
        sounds[index] = sound;
    }
    return index;
}

pub fn allocSoundBuffer() usize {
    for (sounds, 0..) |*sound, index| {
        if (sound.state == .stopped) return index;
    }
    @panic("too many audio sound");
}

pub fn stopSound(sound: SoundHandle) void {
    sounds[sound].state = .stopped;
}

export fn audioCallback(b: [*c]f32, frames: i32, channels: i32) void {
    const buffer = b[0..@as(usize, @intCast(frames * channels))];
    @memset(buffer, 0); // 清空音乐的缓冲区
    if (paused) return;

    fillMusic(buffer, channels);
    fillSound(buffer);
}

fn fillMusic(buffer: []f32, channels: i32) void {
    // 先处理音乐，目前只支持播放一个音乐。
    var len: usize = 0; // 存储填充的长度
    // 因为有可能循环播放，所以循环添加，直到缓冲区填满。
    while (music != null and music.?.state == .playing) {
        const source = music.?.source;
        const count = stbAudio.fillSamples(source, buffer[len..], channels);
        len += @as(usize, @intCast(count * channels));

        if (len == buffer.len) break; // 声音缓冲区填充满了
        if (music.?.loop) stbAudio.reset(source) else music = null;
    }
    // 填充音乐完成，设置音乐的音量
    for (buffer[0..len]) |*sample| sample.* *= musicVolume;
}

fn fillSound(buffer: []f32) void {
    // 填充声音
    for (sounds) |*sound| {
        var len: usize = 0;
        if (sound.state != .playing) continue;
        while (len < buffer.len and sound.state == .playing) {
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
        if (sound.loop) sound.index = 0 else sound.state = .stopped;
    }

    return len;
}

fn mixStereoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len, srcBuffer.len);

    for (0..len) |index| {
        const src = srcBuffer[index] * soundVolume;
        dstBuffer[index] += src;
    }
    sound.index += len;
    return len;
}

fn mixMonoSamples(dstBuffer: []f32, sound: *Sound) usize {
    const srcBuffer = sound.source[sound.index..];
    const len = @min(dstBuffer.len / 2, srcBuffer.len);

    for (0..len) |index| {
        const src = srcBuffer[index] * soundVolume;
        dstBuffer[index * 2] += src;
        dstBuffer[index * 2 + 1] += src;
    }
    sound.index += len;
    return len * 2;
}
