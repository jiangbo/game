const ecs = @import("ecs");

const com = @import("../component.zig");

pub fn update(reg: *ecs.World, delta: f32) void {
    var view = reg.query(.{com.Animation}).reverse();

    while (view.next()) |entity| {
        const animation = reg.getPtr(entity, com.Animation).?;

        // 处理可能的动画播放请求
        if (reg.get(entity, com.animation.Play)) |play| {
            animation.play(play.index);
            animation.source.loop = play.loop;
        }

        switch (animation.update(delta) orelse continue) {
            .next, .loop => {
                // 更新显示的图片
                const sprite = reg.getPtr(entity, com.Sprite).?;
                sprite.image = animation.subImage();
                // 检查是否有动画事件需要触发
                const action = animation.getEnumFrame(com.ActionEnum);
                switch (action) {
                    .hit => reg.add(entity, com.attack.Hit{}),
                    .emit => reg.add(entity, com.attack.Emit{}),
                    .none => {},
                }
            },
            .end => reg.add(entity, com.animation.Finished{}),
        }
    }
    reg.clear(com.animation.Play);
}
