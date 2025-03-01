const std = @import("std");
const Instruct = @import("instruct.zig").Instruct;
const Memory = @import("memory.zig").Memory;

pub const CPU = struct {
    instruct: Instruct = undefined,
    register: [16]u8 = std.mem.zeroes([16]u8),
    index: u16 = 0,
    pc: u16,
    prng: std.rand.DefaultPrng,
    delay: u8 = 0,
    sound: u8 = 0,

    pub fn new(entry: u16) CPU {
        const seed = @as(u64, @intCast(std.time.timestamp()));
        var prng = std.rand.DefaultPrng.init(seed);
        return CPU{
            .pc = entry,
            .prng = prng,
        };
    }

    pub fn cycle(self: *CPU, memory: *Memory) void {
        self.fetch(memory);
        self.decode();
        self.execute(memory);
    }

    pub fn tick(self: *CPU) void {
        if (self.delay > 0) self.delay -= 1;
        if (self.sound > 0) self.sound -= 1;
    }

    fn fetch(self: *CPU, memory: *Memory) void {
        var opcode = memory.load(self.pc);
        self.instruct = Instruct{ .opcode = opcode };
        self.next();
    }

    fn next(self: *CPU) void {
        self.pc += 2;
    }

    fn back(self: *CPU) void {
        self.pc -= 2;
    }

    fn decode(self: *CPU) void {
        self.instruct.decode();
    }

    fn execute(self: *CPU, memory: *Memory) void {
        const ins = &self.instruct;
        var reg = &self.register;
        switch (ins.code) {
            0x0 => {
                if (ins.opcode == 0x00E0) memory.clearScreen();
                if (ins.opcode == 0x00EE) self.pc = memory.pop();
            },
            0x1 => self.pc = ins.nnn,
            0x2 => {
                memory.push(self.pc);
                self.pc = ins.nnn;
            },
            0x3 => if (reg[ins.x] == ins.nn) self.next(),
            0x4 => if (reg[ins.x] != ins.nn) self.next(),
            0x5 => if (reg[ins.x] == reg[ins.y]) self.next(),
            0x6 => reg[ins.x] = ins.nn,
            0x7 => reg[ins.x] +%= ins.nn,
            0x8 => self.code8(reg, ins),
            0x9 => if (reg[ins.x] != reg[ins.y]) self.next(),
            0xA => self.index = ins.nnn,
            0xB => self.pc = reg[0] + ins.nnn,
            0xC => reg[ins.x] = self.prng.random().int(u8) & ins.nn,
            0xD => self.draw(memory),
            0xE => {
                const isPress = memory.isPress(reg[ins.x]);
                if (ins.nn == 0x9E and isPress) self.next();
                if (ins.nn == 0xA1 and !isPress) self.next();
            },
            0xF => self.codef(ins, memory),
        }
    }

    fn code8(self: *CPU, reg: *[16]u8, ins: *Instruct) void {
        switch (ins.n) {
            0x0 => reg[ins.x] = reg[ins.y],
            0x1 => reg[ins.x] |= reg[ins.y],
            0x2 => reg[ins.x] &= reg[ins.y],
            0x3 => reg[ins.x] ^= reg[ins.y],
            0x4 => {
                const sum = @addWithOverflow(reg[ins.x], reg[ins.y]);
                reg[ins.x] = sum.@"0";
                reg[0xF] = sum.@"1";
            },
            0x5 => self.subWithFlag(reg[ins.x], reg[ins.y]),
            0x6 => {
                reg[0xF] = reg[ins.x] & 0x1;
                reg[ins.x] = reg[ins.x] >> 1;
            },
            0x7 => self.subWithFlag(reg[ins.y], reg[ins.x]),
            0xE => {
                reg[0xF] = (reg[ins.x] >> 7) & 0x1;
                reg[ins.x] = reg[ins.x] << 1;
            },
            else => std.log.info("unknown opcode: 0x{X:0>4}", .{ins.opcode}),
        }
    }

    fn subWithFlag(self: *CPU, a: u8, b: u8) void {
        const result = @subWithOverflow(a, b);
        self.register[self.instruct.x] = result.@"0";
        self.register[0xF] = if (result.@"1" == 0) 1 else 0;
    }

    const width: u8 = 0x80;
    fn draw(self: *CPU, memory: *Memory) void {
        self.register[0xF] = 0;
        var rx = self.register[self.instruct.x];
        var ry = self.register[self.instruct.y];
        for (0..self.instruct.n) |row| {
            const sprite = memory.ram[self.index + row];
            for (0..8) |col| {
                const shift = width >> @as(u3, @truncate(col));
                if (sprite & shift == 0) continue;
                if (!memory.setPixel(rx + col, ry + row)) {
                    self.register[0xF] = 1;
                }
            }
        }
    }

    fn codef(self: *CPU, ins: *Instruct, memory: *Memory) void {
        switch (ins.nn) {
            0x07 => self.register[ins.x] = self.delay,
            0x0A => if (memory.getPress()) |index| {
                self.register[ins.x] = index;
            } else self.back(),
            0x15 => self.delay = self.register[ins.x],
            0x18 => self.sound = self.register[ins.x],
            0x1E => self.index += self.register[ins.x],
            0x29 => self.index = self.register[ins.x] * 5,
            0x33 => {
                var num = self.register[ins.x];
                memory.set(self.index + 2, num % 10);
                num /= 10;
                memory.set(self.index + 1, num % 10);
                num /= 10;
                memory.set(self.index, num % 10);
            },
            0x55 => {
                for (0..ins.x + 1) |i| {
                    memory.set(self.index + i, self.register[i]);
                }
            },
            0x65 => {
                for (0..ins.x + 1) |i| {
                    self.register[i] = memory.get(self.index + i);
                }
            },
            else => std.log.info("unknown opcode: 0x{X:0>4}", .{ins.opcode}),
        }
    }
};
