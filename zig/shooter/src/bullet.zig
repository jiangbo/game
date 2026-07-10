const zhu = @import("zhu");

var image: zhu.Image = undefined;

pub fn init() void {
    image = zhu.getImage("image/laser-1.png").?;
}

// pub fn update(delta: f32) void {}
