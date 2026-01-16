const std = @import("std");

const sk = @import("sokol");
const math = @import("math.zig");

const gfx = sk.gfx;
pub const Texture = gfx.View;
pub const Color = gfx.Color;

pub fn queryTextureSize(texture: Texture) math.Vector {
    const image = gfx.queryViewImage(texture);
    return math.Vector{
        .x = @floatFromInt(gfx.queryImageWidth(image)),
        .y = @floatFromInt(gfx.queryImageHeight(image)),
    };
}

pub const RenderPipeline = gfx.Pipeline;
pub const asRange = gfx.asRange;
pub const queryBackend = gfx.queryBackend;
pub const Buffer = gfx.Buffer;
pub const Sampler = gfx.Sampler;
pub const ShaderDesc = gfx.ShaderDesc;
pub const VertexLayoutState = gfx.VertexLayoutState;
pub const ColorTargetState = gfx.ColorTargetState;
pub const createPipeline = gfx.makePipeline;
pub const createShader = gfx.makeShader;

pub var nearestSampler: gfx.Sampler = undefined;
pub var linearSampler: gfx.Sampler = undefined;

pub fn init() void {
    sk.gfx.setup(.{
        .environment = sk.glue.environment(),
        .logger = .{ .func = sk.log.func },
    });
    nearestSampler = gfx.makeSampler(.{});
    linearSampler = gfx.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });
}

pub fn begin(color: Color) void {
    var action = gfx.PassAction{};

    action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
    gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
}

pub fn setPipeline(pipeline: RenderPipeline) void {
    gfx.applyPipeline(pipeline);
}

pub fn setUniform(index: u32, uniform: anytype) void {
    gfx.applyUniforms(index, gfx.asRange(&uniform));
}

pub fn setBindGroup(group: BindGroup) void {
    gfx.applyBindings(group.value);
}

pub fn drawInstanced(number: usize) void {
    gfx.draw(0, 4, @intCast(number));
}

pub fn end() void {
    gfx.endPass();
    gfx.commit();
}

pub fn scissor(area: math.Rect) void {
    const x, const y = .{ area.min.x, area.min.y };
    gfx.applyScissorRectf(x, y, area.size.x, area.size.y, true);
}

pub fn createBuffer(desc: gfx.BufferDesc) Buffer {
    return gfx.makeBuffer(desc);
}

pub fn appendBuffer(buffer: Buffer, data: anytype) void {
    _ = gfx.appendBuffer(buffer, gfx.asRange(data));
}

pub fn updateBuffer(buffer: Buffer, data: anytype) void {
    _ = gfx.updateBuffer(buffer, gfx.asRange(data));
}

pub fn frameStats(enable: bool) void {
    if (enable) gfx.enableFrameStats() else gfx.disableFrameStats();
}

pub fn queryFrameStats() gfx.FrameStats {
    return gfx.queryFrameStats();
}

pub const BindGroup = struct {
    value: gfx.Bindings = .{},

    pub fn setVertexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.vertex_buffers[0] = buffer;
    }

    pub fn setVertexOffset(self: *BindGroup, offset: usize) void {
        self.value.vertex_buffer_offsets[0] = @intCast(offset);
    }

    pub fn setTexture(self: *BindGroup, texture: Texture) void {
        self.value.views[0] = texture;
    }

    pub fn setSampler(self: *BindGroup, sampler: sk.gfx.Sampler) void {
        self.value.samplers[0] = sampler;
    }
};
