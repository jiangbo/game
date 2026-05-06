const std = @import("std");
const zhu = @import("zhu");

const com = @import("../component.zig");

pub fn update(reg: *zhu.ecs.Registry, delta: f32) void {
    const timerEvents = reg.getEvents(com.Timer);

    var iterator = std.mem.reverseIterator(timerEvents.items);
    while (iterator.nextPtr()) |timer| {
        timer.remaining -= delta;
        if (timer.remaining > 0) continue;

        switch (timer.type) {
            .attack => reg.add(timer.entity, com.attack.Ready{}),
        }
        _ = timerEvents.swapRemove(iterator.index);
    }
}
