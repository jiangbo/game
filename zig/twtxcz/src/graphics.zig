const std = @import("std");
const zm = @import("zmath");
const sk = @import("sokol");

const context = @import("context.zig");
const batch = @import("shader/batch.glsl.zig");

pub const Camera = struct {
    proj: zm.Mat,

    pub fn init(width: f32, height: f32) Camera {
        const proj = zm.orthographicOffCenterLh(0, width, 0, height, 0, 1);
        return .{ .proj = proj };
    }

    pub fn vp(self: Camera) zm.Mat {
        return self.proj;
    }
};

pub const BatchInstance = batch.Batchinstance;
pub const UniformParams = batch.VsParams;
pub const Image = sk.gfx.Image;
pub const Texture = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32,
    height: f32,
    value: sk.gfx.Image,

    pub fn init(width: u32, height: u32, data: []u8) Texture {
        const image = sk.gfx.allocImage();

        sk.gfx.initImage(image, .{
            .width = @as(i32, @intCast(width)),
            .height = @as(i32, @intCast(height)),
            .pixel_format = .RGBA8,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.subimage[0][0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });

        return .{
            .width = @floatFromInt(width),
            .height = @floatFromInt(height),
            .value = image,
        };
    }
};

pub const Color = sk.gfx.Color;
pub const Buffer = sk.gfx.Buffer;

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},
    uniform: batch.VsParams = undefined,

    pub fn bindIndexBuffer(self: *BindGroup, buffer: Buffer) void {
        self.value.index_buffer = buffer;
    }

    pub fn bindVertexBuffer(self: *BindGroup, index: u32, buffer: Buffer) void {
        self.value.vertex_buffers[index] = buffer;
    }

    pub fn bindTexture(self: *BindGroup, index: u32, texture: Texture) void {
        self.value.images[index] = texture.value;
    }

    pub fn bindSampler(self: *BindGroup, index: u32, sampler: Sampler) void {
        self.value.samplers[index] = sampler.value;
    }

    pub fn bindStorageBuffer(self: *BindGroup, index: u32, buffer: Buffer) void {
        self.value.storage_buffers[index] = buffer;
    }

    pub fn updateStorageBuffer(self: *BindGroup, index: u32, data: anytype) void {
        const range = sk.gfx.asRange(data);
        sk.gfx.updateBuffer(self.value.storage_buffers[index], range);
    }

    pub fn bindUniformBuffer(self: *BindGroup, uniform: UniformParams) void {
        self.uniform = uniform;
    }
};

pub const CommandEncoder = struct {
    pub fn beginRenderPass(color: Color) RenderPass {
        return RenderPass.begin(color);
    }
};

pub const RenderPass = struct {
    pub fn begin(color: Color) RenderPass {
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPass{};
    }

    pub fn setPipeline(self: *RenderPass, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPass, group: BindGroup) void {
        _ = self;
        sk.gfx.applyUniforms(batch.UB_vs_params, sk.gfx.asRange(&group.uniform));
        sk.gfx.applyBindings(group.value);
    }

    pub fn draw(self: *RenderPass, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn submit(self: *RenderPass) void {
        _ = self;
        sk.gfx.endPass();
        sk.gfx.commit();
    }
};

pub const Sampler = struct {
    value: sk.gfx.Sampler,

    pub fn liner() Sampler {
        const sampler = sk.gfx.makeSampler(.{
            .min_filter = .LINEAR,
            .mag_filter = .LINEAR,
        });
        return .{ .value = sampler };
    }

    pub fn nearest() Sampler {
        const sampler = sk.gfx.makeSampler(.{
            .min_filter = .NEAREST,
            .mag_filter = .NEAREST,
        });
        return .{ .value = sampler };
    }
};

const Allocator = std.mem.Allocator;

pub const BatchBuffer = struct {
    const size: usize = 100;

    cpu: std.ArrayListUnmanaged(BatchInstance),
    gpu: Buffer,

    pub fn init(alloc: Allocator) Allocator.Error!BatchBuffer {
        return .{
            .cpu = try std.ArrayListUnmanaged(BatchInstance).initCapacity(alloc, size),
            .gpu = sk.gfx.makeBuffer(.{
                .type = .STORAGEBUFFER,
                .usage = .DYNAMIC,
                .size = size * @sizeOf(BatchInstance),
            }),
        };
    }

    pub fn deinit(self: *BatchBuffer, alloc: Allocator) void {
        self.cpu.deinit(alloc);
    }
};

pub const TextureBatch = struct {
    bind: BindGroup = .{},
    texture: Texture,
    renderPass: RenderPass,
    buffer: BatchBuffer,

    var pipeline: ?RenderPipeline = null;

    pub fn begin(renderPass: RenderPass, texture: Texture) TextureBatch {
        var textureBatch = TextureBatch{
            .texture = texture,
            .renderPass = renderPass,
            .buffer = context.batchBuffer,
        };

        textureBatch.bind.bindUniformBuffer(UniformParams{ .vp = context.camera.vp() });
        textureBatch.bind.bindStorageBuffer(0, textureBatch.buffer.gpu);
        textureBatch.bind.bindTexture(batch.IMG_tex, texture);
        textureBatch.bind.bindSampler(batch.SMP_smp, context.textureSampler);

        pipeline = pipeline orelse RenderPipeline{ .value = sk.gfx.makePipeline(.{
            .shader = sk.gfx.makeShader(batch.batchShaderDesc(sk.gfx.queryBackend())),
            .colors = init: {
                var c: [4]sk.gfx.ColorTargetState = @splat(.{});
                c[0] = .{ .blend = .{
                    .enabled = true,
                    .src_factor_rgb = .SRC_ALPHA,
                    .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                } };
                break :init c;
            },
            .depth = .{
                .compare = .LESS_EQUAL,
                .write_enabled = true,
            },
            .cull_mode = .BACK,
        }) };

        return textureBatch;
    }

    pub fn draw(self: *TextureBatch, x: f32, y: f32) void {
        self.buffer.cpu.appendAssumeCapacity(.{
            .position = .{ x, y, 0.5, 1.0 },
            .rotation = 0.0,
            .width = self.texture.width,
            .height = self.texture.height,
            .padding = 0.0,
            .texcoord = .{ 0.0, 0.0, 1.0, 1.0 },
            .color = .{ 1.0, 1.0, 1.0, 1.0 },
        });
    }

    pub fn end(self: *TextureBatch) void {
        self.renderPass.setPipeline(pipeline.?);
        self.bind.updateStorageBuffer(0, self.buffer.cpu.items);
        self.renderPass.setBindGroup(self.bind);
        self.renderPass.draw(6 * @as(u32, @intCast(self.buffer.cpu.items.len)));
    }
};

pub const TextureSingle = struct {
    bind: BindGroup,
    renderPass: RenderPass,

    const single = @import("shader/single.glsl.zig");
    var indexBuffer: ?Buffer = null;
    var pipeline: ?RenderPipeline = null;

    pub fn begin(renderPass: RenderPass) TextureSingle {
        var self = TextureSingle{ .bind = .{}, .renderPass = renderPass };

        indexBuffer = indexBuffer orelse sk.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sk.gfx.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
        });
        self.bind.bindIndexBuffer(indexBuffer.?);

        self.bind.bindSampler(single.SMP_smp, context.textureSampler);

        pipeline = pipeline orelse RenderPipeline{
            .value = sk.gfx.makePipeline(.{
                .shader = sk.gfx.makeShader(single.singleShaderDesc(sk.gfx.queryBackend())),
                .layout = init: {
                    var l = sk.gfx.VertexLayoutState{};
                    l.attrs[single.ATTR_single_position].format = .FLOAT3;
                    l.attrs[single.ATTR_single_color0].format = .FLOAT3;
                    l.attrs[single.ATTR_single_texcoord0].format = .FLOAT2;
                    break :init l;
                },
                .colors = init: {
                    var c: [4]sk.gfx.ColorTargetState = @splat(.{});
                    c[0] = .{
                        .blend = .{
                            .enabled = true,
                            .src_factor_rgb = .SRC_ALPHA,
                            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                        },
                    };
                    break :init c;
                },
                .index_type = .UINT16,
                .depth = .{
                    .compare = .LESS_EQUAL,
                    .write_enabled = true,
                },
            }),
        };

        return self;
    }

    pub fn draw(self: *TextureSingle, x: f32, y: f32, tex: Texture) void {
        const vertexBuffer = sk.gfx.makeBuffer(.{
            .data = sk.gfx.asRange(&[_]f32{
                // 顶点和颜色
                x,             y + tex.height, 0.5, 1.0, 1.0, 1.0, 0, 1,
                x + tex.width, y + tex.height, 0.5, 1.0, 1.0, 1.0, 1, 1,
                x + tex.width, y,              0.5, 1.0, 1.0, 1.0, 1, 0,
                x,             y,              0.5, 1.0, 1.0, 1.0, 0, 0,
            }),
        });

        const params = UniformParams{ .vp = context.camera.vp() };
        self.bind.bindUniformBuffer(params);
        self.bind.bindVertexBuffer(0, vertexBuffer);

        self.renderPass.setPipeline(pipeline.?);
        self.bind.bindTexture(single.IMG_tex, tex);
        self.renderPass.setBindGroup(self.bind);
        sk.gfx.draw(0, 6, 1);
        sk.gfx.destroyBuffer(vertexBuffer);
    }

    pub fn end(self: *TextureSingle) void {
        _ = self;
        sk.gfx.endPass();
    }
};

pub const RenderPipeline = struct {
    value: sk.gfx.Pipeline,
};
