const std = @import("std");
const sk = @import("sokol");

const render = @import("shader/single.glsl.zig");
const math = @import("math.zig");

pub const Color = sk.gfx.Color;
pub const Buffer = sk.gfx.Buffer;

pub const Texture = struct {
    value: sk.gfx.Image,

    pub fn init(w: u32, h: u32, data: []const u8) Texture {
        const image = sk.gfx.allocImage();

        sk.gfx.initImage(image, .{
            .width = @as(i32, @intCast(w)),
            .height = @as(i32, @intCast(h)),
            .pixel_format = .RGBA8,
            .data = init: {
                var imageData = sk.gfx.ImageData{};
                imageData.subimage[0][0] = sk.gfx.asRange(data);
                break :init imageData;
            },
        });

        return .{ .value = image };
    }

    pub fn width(self: Texture) f32 {
        return @floatFromInt(sk.gfx.queryImageWidth(self.value));
    }

    pub fn height(self: Texture) f32 {
        return @floatFromInt(sk.gfx.queryImageHeight(self.value));
    }

    pub fn size(self: Texture) math.Vector {
        return .{ .x = self.width(), .y = self.height(), .z = 1 };
    }

    pub fn deinit(self: *Texture) void {
        sk.gfx.destroyImage(self.value);
    }
};

pub const BindGroup = struct {
    value: sk.gfx.Bindings = .{},
    uniform: render.VsParams = undefined,

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

    pub fn bindUniformBuffer(self: *BindGroup, uniform: UniformParams) void {
        self.uniform = uniform;
    }
};

pub const CommandEncoder = struct {
    pub fn beginRenderPass(color: Color, matrix: []const f32) RenderPassEncoder {
        sk.gl.defaults();
        sk.gl.matrixModeModelview();
        sk.gl.loadMatrix(@ptrCast(matrix));
        sk.gl.pushMatrix();
        return RenderPassEncoder.begin(color);
    }
};

pub const Rectangle = math.Rectangle;

pub const RenderPassEncoder = struct {
    pub fn begin(color: Color) RenderPassEncoder {
        var action = sk.gfx.PassAction{};
        action.colors[0] = .{ .load_action = .CLEAR, .clear_value = color };
        sk.gfx.beginPass(.{ .action = action, .swapchain = sk.glue.swapchain() });
        return RenderPassEncoder{};
    }

    pub fn setPipeline(self: *RenderPassEncoder, pipeline: RenderPipeline) void {
        _ = self;
        sk.gfx.applyPipeline(pipeline.value);
    }

    pub fn setBindGroup(self: *RenderPassEncoder, group: BindGroup) void {
        _ = self;
        sk.gfx.applyUniforms(render.UB_vs_params, sk.gfx.asRange(&group.uniform));
        sk.gfx.applyBindings(group.value);
    }

    pub fn draw(self: *RenderPassEncoder, number: u32) void {
        _ = self;
        sk.gfx.draw(0, number, 1);
    }

    pub fn submit(self: *RenderPassEncoder) void {
        _ = self;
        sk.gl.popMatrix();
        sk.gl.draw();
        sk.gfx.endPass();
        sk.gfx.commit();
    }
};

const UniformParams = render.VsParams;

pub const Renderer = struct {
    bind: BindGroup,
    renderPass: RenderPassEncoder,

    var indexBuffer: ?Buffer = null;
    var pipeline: ?RenderPipeline = null;
    var sampler: ?Sampler = null;

    pub fn init() Renderer {
        sk.gfx.setup(.{
            .environment = sk.glue.environment(),
            .logger = .{ .func = sk.log.func },
            .image_pool_size = 150,
        });

        sk.gl.setup(.{
            .logger = .{ .func = sk.log.func },
        });

        sk.debugtext.setup(.{
            .fonts = init: {
                var f: [8]sk.debugtext.FontDesc = @splat(.{});
                f[0] = sk.debugtext.fontKc854();
                break :init f;
            },
            .logger = .{ .func = sk.log.func },
        });

        var self = Renderer{ .bind = .{}, .renderPass = undefined };

        indexBuffer = indexBuffer orelse sk.gfx.makeBuffer(.{
            .type = .INDEXBUFFER,
            .data = sk.gfx.asRange(&[_]u16{ 0, 1, 2, 0, 2, 3 }),
        });
        self.bind.bindIndexBuffer(indexBuffer.?);

        sampler = sampler orelse Sampler.nearest();
        self.bind.bindSampler(render.SMP_smp, sampler.?);

        pipeline = pipeline orelse RenderPipeline{
            .value = sk.gfx.makePipeline(.{
                .shader = sk.gfx.makeShader(render.singleShaderDesc(sk.gfx.queryBackend())),
                .layout = init: {
                    var l = sk.gfx.VertexLayoutState{};
                    l.attrs[render.ATTR_single_position].format = .FLOAT3;
                    l.attrs[render.ATTR_single_color0].format = .FLOAT3;
                    l.attrs[render.ATTR_single_texcoord0].format = .FLOAT2;
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
                .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
            }),
        };

        return self;
    }

    pub const DrawOptions = struct {
        uniform: UniformParams,
        texture: Texture,
        sourceRect: Rectangle,
        targetRect: Rectangle,
        radians: f32 = 0,
        pivot: math.Vector = .zero,
    };

    pub fn draw(self: *Renderer, options: DrawOptions) void {
        const dst = options.targetRect;

        const pos = options.sourceRect.position.div(options.texture.size());
        const size = options.sourceRect.size.div(options.texture.size());

        var vertex = [_]math.Vector3{
            .{ .x = dst.position.x, .y = dst.bottom() },
            .{ .x = dst.right(), .y = dst.bottom() },
            .{ .x = dst.right(), .y = dst.position.y },
            .{ .x = dst.position.x, .y = dst.position.y },
        };

        if (options.radians != 0) {
            const percent = options.pivot.div(options.texture.size());
            const pivot = dst.position.add(percent.mul(dst.size));

            for (&vertex) |*point| {
                point.* = pivot.add(point.sub(pivot).rotate(options.radians));
            }
        }

        const vertexBuffer = sk.gfx.makeBuffer(.{
            .data = sk.gfx.asRange(&[_]f32{
                // 顶点和颜色
                vertex[0].x, vertex[0].y, 0.5, 1.0, 1.0, 1.0, pos.x,  size.y,
                vertex[1].x, vertex[1].y, 0.5, 1.0, 1.0, 1.0, size.x, size.y,
                vertex[2].x, vertex[2].y, 0.5, 1.0, 1.0, 1.0, size.x, pos.y,
                vertex[3].x, vertex[3].y, 0.5, 1.0, 1.0, 1.0, pos.x,  pos.y,
            }),
        });

        self.bind.bindVertexBuffer(0, vertexBuffer);
        self.bind.bindUniformBuffer(options.uniform);

        self.renderPass.setPipeline(pipeline.?);
        self.bind.bindTexture(render.IMG_tex, options.texture);
        self.renderPass.setBindGroup(self.bind);
        sk.gfx.draw(0, 6, 1);
        sk.gfx.destroyBuffer(vertexBuffer);
    }
};

pub fn deinit() void {
    sk.gfx.shutdown();
}

pub const RenderPipeline = struct {
    value: sk.gfx.Pipeline,
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

pub fn drawRectangleLine(rect: Rectangle) void {
    sk.gl.beginLineStrip();

    sk.gl.v2fC3b(rect.x, rect.y, 0, 255, 0);
    sk.gl.v2fC3b(rect.right(), rect.y, 0, 255, 0);
    sk.gl.v2fC3b(rect.right(), rect.bottom(), 0, 255, 0);
    sk.gl.v2fC3b(rect.x, rect.bottom(), 0, 255, 0);
    sk.gl.v2fC3b(rect.x, rect.y, 0, 255, 0);

    sk.gl.end();
}
