const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Entity = struct {
    const Index = u16;
    const Version = u16;
    const invalid = std.math.maxInt(Index);

    index: Index,
    version: Version,
};

const Entities = struct {
    versions: std.ArrayList(Entity.Version) = .empty,
    deleted: std.ArrayList(Entity.Index) = .empty,

    pub fn deinit(self: *Entities, gpa: Allocator) void {
        self.versions.deinit(gpa);
        self.deleted.deinit(gpa);
    }

    pub fn create(self: *Entities, gpa: Allocator) !Entity {
        if (self.deleted.pop()) |index| {
            const version = self.versions.items[index];
            return .{ .index = index, .version = version };
        } else {
            const index = self.versions.items.len;
            if (index == Entity.invalid) @panic("max entity index");
            try self.versions.append(gpa, 0);
            return .{ .index = @intCast(index), .version = 0 };
        }
    }

    pub fn destroy(self: *Entities, gpa: Allocator, entity: Entity) !void {
        self.versions.items[entity.index] +%= 1;
        try self.deleted.append(gpa, entity.index);
    }

    pub fn isAlive(self: *const Entities, entity: Entity) bool {
        return entity.index < self.versions.items.len and
            self.versions.items[entity.index] == entity.version;
    }

    pub fn toEntity(self: *const Entities, index: Entity.Index) ?Entity {
        if (index < self.versions.items.len) {
            const version = self.versions.items[index];
            return .{ .index = index, .version = version };
        } else return null;
    }
};

pub fn SparseMap(T: type) type {
    return struct {
        const Self = @This();
        const Index = Entity.Index;

        sparse: std.ArrayList(Index) = .empty,
        dense: std.ArrayList(Index) = .empty,
        alignment: std.mem.Alignment = .of(T),
        valuePtr: [*]T = undefined,
        valueSize: u16 = @sizeOf(T),
        alignIndex: Index = 0,
        deletedIndex: Index = Entity.invalid,

        pub fn deinit(self: *Self, gpa: Allocator) void {
            self.sparse.deinit(gpa);
            const capacity = self.dense.capacity;
            self.dense.deinit(gpa);
            if (capacity == 0 or self.valueSize == 0) return;

            const size = if (T == u8) self.valueSize else 1;
            const slice = self.valuePtr[0 .. capacity * size];
            gpa.rawFree(slice, self.alignment, @returnAddress());
        }

        pub fn has(self: *const Self, entity: Index) bool {
            return entity < self.sparse.items.len and
                self.sparse.items[entity] != Entity.invalid;
        }

        pub fn add(self: *Self, gpa: Allocator, e: Index, v: T) !void {
            if (self.has(e)) { // repeat add
                if (self.valueSize != 0) self.get(e).* = v;
            } else if (self.deletedIndex != Entity.invalid) {
                const index = self.deletedIndex;
                self.deletedIndex = self.dense.items[index];

                self.sparse.items[e] = index;
                self.dense.items[index] = e;
                if (self.valueSize != 0) self.valuePtr[index] = v;
            } else try self.doAdd(gpa, e, v);
        }

        fn doAdd(self: *Self, gpa: Allocator, e: Index, v: T) !void {
            if (e >= self.sparse.items.len) {
                const count = e + 1 - self.sparse.items.len;
                try self.sparse.appendNTimes(gpa, Entity.invalid, count);
            }

            const index: u16 = @intCast(self.dense.items.len);
            const oldCapacity = self.dense.capacity;
            try self.dense.append(gpa, e);
            errdefer _ = self.dense.pop();
            if (self.valueSize != 0) {
                if (oldCapacity != self.dense.capacity) {
                    const slice = self.valuePtr[0..oldCapacity];
                    const capacity = self.dense.capacity;
                    self.valuePtr = (try gpa.realloc(slice, capacity)).ptr;
                }
                self.valuePtr[index] = v;
            }
            self.sparse.items[e] = index;
        }

        pub fn get(self: *const Self, entity: Index) *T {
            std.debug.assert(self.valueSize != 0);
            return &self.valuePtr[self.sparse.items[entity]];
        }

        pub fn tryGet(self: *const Self, entity: Index) ?*T {
            return if (self.has(entity)) self.get(entity) else null;
        }

        pub fn components(self: *const Self) []T {
            std.debug.assert(self.valueSize != 0);
            std.debug.assert(self.deletedIndex == Entity.invalid);
            return self.valuePtr[0..self.dense.items.len];
        }

        pub fn markRemove(self: *Self, entity: Index) void {
            if (!self.has(entity)) return;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = Entity.invalid;

            self.dense.items[index] = self.deletedIndex;
            self.deletedIndex = index;
        }

        pub fn swapRemove(self: *Self, entity: Index) Index {
            if (!self.has(entity)) return Entity.invalid;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = Entity.invalid;

            const moved = self.dense.pop().?;
            if (self.dense.items.len == index) return index;
            self.sparse.items[moved] = index;
            self.dense.items[index] = moved;
            if (self.valueSize == 0) return index;

            const sz = if (T == u8) self.valueSize else 1;
            const src = self.valuePtr[sz * self.dense.items.len ..];
            @memcpy(self.valuePtr[sz * index ..][0..sz], src[0..sz]);
            return index;
        }

        pub fn orderedRemove(self: *Self, entity: Index) void {
            if (!self.has(entity)) return;

            const index = self.sparse.items[entity];
            self.sparse.items[entity] = Entity.invalid;
            _ = self.dense.orderedRemove(index);
            for (self.dense.items[index..]) |e| self.sparse.items[e] -= 1;
            if (self.valueSize == 0) return;

            const sz = if (T == u8) self.valueSize else 1;
            const len = (self.dense.items.len - index) * sz;
            const src = self.valuePtr[sz * (index + 1) ..][0..len];
            @memmove(self.valuePtr[sz * index ..][0..len], src);
        }

        pub fn sort(self: *Self, lessFn: fn (T, T) bool) void {
            std.debug.assert(self.deletedIndex == Entity.invalid);
            if (self.dense.items.len <= 1 or self.valueSize == 0) return;

            const sparse = self.sparse.items;
            const v = self.valuePtr[0..self.dense.items.len];
            for (0..v.len) |i| {
                var j = i;
                while (j > 0 and lessFn(v[j], v[j - 1])) : (j -= 1) {
                    std.mem.swap(T, &v[j], &v[j - 1]);
                    const lhs = &self.dense.items[j];
                    const rhs = &self.dense.items[j - 1];
                    std.mem.swap(Index, lhs, rhs);
                    std.mem.swap(u16, &sparse[lhs.*], &sparse[rhs.*]);
                }
            }
        }

        pub fn clear(self: *Self) void {
            self.deletedIndex = Entity.invalid;
            @memset(self.sparse.items, Entity.invalid);
            self.dense.clearRetainingCapacity();
        }
    };
}

fn DeinitList(T: type) type {
    return struct {
        list: std.ArrayList(T) = .empty,
        alignment: std.mem.Alignment = .of(T),
        valueSize: u32 = @sizeOf(T),

        fn deinit(self: *@This(), gpa: Allocator) void {
            if (self.list.capacity == 0) return;
            const size = self.list.capacity * self.valueSize;
            const slice = self.list.items.ptr[0..size];
            gpa.rawFree(slice, self.alignment, @returnAddress());
        }
    };
}

pub const TypeId = u64;
const Map = std.AutoHashMapUnmanaged;
pub const Registry = struct {
    allocator: Allocator,
    entities: Entities = .{},
    componentMap: Map(TypeId, [@sizeOf(SparseMap(u8))]u8) = .empty,

    identityMap: Map(TypeId, Entity) = .empty,
    contextMap: Map(TypeId, []u8) = .empty,
    eventMap: Map(TypeId, [@sizeOf(DeinitList(u8))]u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Registry) void {
        self.entities.deinit(self.allocator);
        self.identityMap.deinit(self.allocator);

        var it = self.contextMap.valueIterator();
        while (it.next()) |value| self.allocator.free(value.*);
        self.contextMap.deinit(self.allocator);

        var events = self.eventMap.valueIterator();
        while (events.next()) |value| {
            var list: *DeinitList(u8) = @ptrCast(@alignCast(value));
            list.deinit(self.allocator);
        }
        self.eventMap.deinit(self.allocator);

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var map: *SparseMap(u8) = @ptrCast(@alignCast(value));
            map.deinit(self.allocator);
        }
        self.componentMap.deinit(self.allocator);
    }

    pub fn createEntity(self: *Registry) Entity {
        return self.entities.create(self.allocator) catch oom();
    }

    pub fn validEntity(self: *const Registry, entity: ?Entity) bool {
        return self.entities.isAlive(entity orelse return false);
    }

    pub fn destroyEntity(self: *Registry, entity: ?Entity) void {
        if (!self.validEntity(entity)) return;
        self.removeAll(entity.?);
        self.entities.destroy(self.allocator, entity.?) catch oom();
    }

    pub fn addContext(self: *Registry, value: anytype) void {
        const id = hashTypeId(@TypeOf(value));
        const v = self.contextMap.getOrPut(self.allocator, id) catch oom();
        if (!v.found_existing) {
            const size = @sizeOf(@TypeOf(value));
            v.value_ptr.* = self.allocator.alloc(u8, size) catch oom();
        }
        @memcpy(v.value_ptr.*, std.mem.asBytes(&value));
    }

    pub fn getContext(self: *Registry, T: type) ?T {
        return (self.getContextPtr(T) orelse return null).*;
    }

    pub fn getContextPtr(self: *Registry, T: type) ?*T {
        const ptr = self.contextMap.get(hashTypeId(T));
        return @ptrCast(ptr orelse return null);
    }

    pub fn removeContext(self: *Registry, T: type) void {
        const removed = self.contextMap.fetchRemove(hashTypeId(T));
        if (removed) |entry| self.allocator.free(entry.value);
    }

    pub fn addIdentity(self: *Registry, e: Entity, T: type) void {
        const id = hashTypeId(T);
        self.identityMap.put(self.allocator, id, e) catch oom();
    }

    pub fn createIdentityEntity(self: *Registry, T: type) Entity {
        const entity = self.createEntity();
        self.addIdentity(entity, T);
        return entity;
    }

    pub fn getIdentityEntity(self: *Registry, T: type) ?Entity {
        return self.identityMap.get(hashTypeId(T));
    }

    pub fn getIdentity(self: *Registry, T: type, V: type) ?V {
        const entity = self.getIdentityEntity(T) orelse return null;
        return self.get(entity, V);
    }

    pub fn isIdentity(self: *Registry, e: Entity, T: type) bool {
        const e1 = self.getIdentityEntity(T) orelse return false;
        return e1.index == e.index and e1.version == e.version;
    }

    pub fn removeIdentity(self: *Registry, T: type) bool {
        return self.identityMap.remove(hashTypeId(T));
    }

    fn assureEvent(self: *Registry, T: type) *std.ArrayList(T) {
        const v = self.eventMap.getOrPut(self.allocator, //
            hashTypeId(T)) catch oom();
        if (!v.found_existing) {
            v.value_ptr.* = std.mem.toBytes(DeinitList(T){});
        }
        var list: *DeinitList(T) = @ptrCast(@alignCast(v.value_ptr));
        return &list.list;
    }

    pub fn addEvent(self: *Registry, value: anytype) void {
        var list = self.assureEvent(@TypeOf(value));
        list.append(self.allocator, value) catch oom();
    }

    pub fn getEvents(self: *Registry, T: type) []T {
        return self.assureEvent(T).items;
    }

    pub fn popEvent(self: *Registry, T: type) ?T {
        return self.assureEvent(T).pop();
    }

    pub fn clearEvent(self: *Registry, T: type) void {
        self.assureEvent(T).clearRetainingCapacity();
    }

    pub fn removeEvent(self: *Registry, T: type) bool {
        self.assureEvent(T).deinit(self.allocator);
        return self.eventMap.remove(hashTypeId(T));
    }

    pub fn assure(self: *Registry, T: type) *SparseMap(T) {
        const result = self.componentMap
            .getOrPut(self.allocator, hashTypeId(T)) catch oom();

        if (!result.found_existing) {
            result.value_ptr.* = std.mem.toBytes(SparseMap(T){});
        }
        return @ptrCast(@alignCast(result.value_ptr));
    }

    pub fn add(self: *Registry, entity: Entity, value: anytype) void {
        if (!self.validEntity(entity)) return;
        var map = self.assure(@TypeOf(value));
        map.add(self.allocator, entity.index, value) catch oom();
    }

    pub fn alignAdd(self: *Registry, e: Entity, comps: anytype) void {
        if (!self.validEntity(e)) return;
        var index: [comps.len]Entity.Index = undefined;
        inline for (comps, &index) |value, *i| {
            var map = self.assure(@TypeOf(value));
            map.add(self.allocator, e.index, value) catch oom();
            i.* = map.sparse.items[e.index] + map.alignIndex;
        }
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn has(self: *Registry, entity: Entity, T: type) bool {
        if (!self.validEntity(entity)) return false;
        return self.assure(T).has(entity.index);
    }

    pub fn get(self: *Registry, entity: Entity, T: type) T {
        return self.tryGet(entity, T).?;
    }

    pub fn tryGet(self: *Registry, entity: Entity, T: type) ?T {
        return (self.tryGetPtr(entity, T) orelse return null).*;
    }

    pub fn getPtr(self: *Registry, entity: Entity, T: type) *T {
        return self.tryGetPtr(entity, T).?;
    }

    pub fn tryGetPtr(self: *Registry, entity: Entity, T: type) ?*T {
        if (!self.validEntity(entity)) return null;
        return self.assure(T).tryGet(entity.index);
    }

    pub fn raw(self: *Registry, T: type) []T {
        return self.assure(T).components();
    }

    pub fn indexes(self: *Registry, T: type) //
    struct { []Entity.Index, View(.{T}, .{}, false) } {
        return .{ self.assure(T).dense.items, self.view(.{T}) };
    }

    pub fn sort(self: *Registry, T: type, lessFn: fn (T, T) bool) void {
        self.assure(T).sort(lessFn);
    }

    pub fn swapRemove(self: *Registry, entity: Entity, T: type) void {
        if (!self.validEntity(entity)) return;
        _ = self.assure(T).swapRemove(entity.index);
    }

    pub fn orderedRemove(self: *Registry, e: Entity, T: type) void {
        if (!self.validEntity(e)) return;
        self.assure(T).orderedRemove(e.index);
    }

    pub fn alignRemove(self: *Registry, e: Entity, types: anytype) void {
        if (!self.validEntity(e)) return;
        var index: [types.len]u16 = undefined;
        inline for (types, &index) |T, *i| {
            var map = self.assure(T);
            i.* = map.swapRemove(e.index);
            if (i.* != Entity.invalid) i.* +% map.alignIndex;
        }
        for (index[1..]) |i| std.debug.assert(index[0] == i);
    }

    pub fn removeAll(self: *Registry, entity: Entity) void {
        if (!self.validEntity(entity)) return;

        var iterator = self.componentMap.valueIterator();
        while (iterator.next()) |value| {
            var map: *SparseMap(u8) = @ptrCast(@alignCast(value));
            _ = map.swapRemove(entity.index);
        }
    }

    pub fn clear(self: *Registry, T: type) void {
        self.assure(T).clear();
    }

    pub fn clearAll(self: *Registry, types: anytype) void {
        inline for (types) |T| self.clear(T);
    }

    pub fn view(self: *Registry, types: anytype) View(types, .{}, .{}) {
        return self.viewOption(types, .{}, .{});
    }
    // zig fmt: off
    pub fn viewOption(self: *Registry, includes: anytype, excludes: anytype,
        comptime opt: ViewOption) View(includes, excludes, opt) {
    // zig fmt: on
        return View(includes, excludes, opt).init(self);
    }
};

pub const ViewOption = struct {
    reverse: bool = false,
    useFirst: bool = false, // use shortest or first?
};
pub fn View(includes: anytype, excludes: anytype, opt: ViewOption) type {
    const Index = Entity.Index;
    return struct {
        reg: *Registry,
        slice: []Index = &.{},
        index: Index,

        pub fn init(r: *Registry) @This() {
            var slice = r.assure(includes[0]).dense.items;
            if (!opt.useFirst) {
                inline for (includes) |T| {
                    const entities = r.assure(T).dense.items;
                    if (entities.len < slice.len) slice = entities;
                }
            }
            const index = if (opt.reverse) slice.len - 1 else 0;
            return .{ .reg = r, .slice = slice, .index = @intCast(index) };
        }

        pub fn next(self: *@This()) ?Index {
            blk: while (self.index < self.slice.len) {
                const entity = self.slice[self.index];
                if (opt.reverse) self.index -%= 1 else self.index += 1;

                inline for (includes) |T| {
                    if (!self.has(entity, T)) continue :blk;
                }
                inline for (excludes) |T| {
                    if (self.has(entity, T)) continue :blk;
                }
                return entity;
            } else return null;
        }

        pub fn assure(self: *@This(), T: type) *SparseMap(T) {
            return self.reg.assure(T);
        }

        pub fn get(self: *@This(), entity: Index, T: type) T {
            return self.getPtr(entity, T).*;
        }

        pub fn tryGet(self: *@This(), entity: Index, T: type) ?T {
            return (self.tryGetPtr(entity, T) orelse return null).*;
        }

        pub fn getPtr(self: *@This(), entity: Index, T: type) *T {
            return self.reg.assure(T).get(entity);
        }

        pub fn tryGetPtr(self: *@This(), entity: Index, T: type) ?*T {
            return self.reg.assure(T).tryGet(entity);
        }

        pub fn has(self: *const @This(), entity: Index, T: type) bool {
            return self.reg.assure(T).has(entity);
        }

        pub fn is(self: *const @This(), entity: Index, T: type) bool {
            const e = self.reg.getIdentityEntity(T) orelse return false;
            return e.index == entity;
        }

        pub fn add(self: *@This(), entity: Index, value: anytype) void {
            const map = self.assure(@TypeOf(value));
            map.add(self.reg.allocator, entity, value) catch oom();
        }

        pub fn toEntity(self: *const @This(), index: Index) ?Entity {
            return self.reg.entities.toEntity(index);
        }

        pub fn remove(self: *@This(), entity: Index, T: type) void {
            _ = self.reg.assure(T).swapRemove(entity);
        }

        pub fn destroy(self: *@This(), entity: Index) void {
            self.reg.destroyEntity(self.toEntity(entity));
        }
    };
}

fn oom() noreturn {
    @panic("oom");
}
pub fn hashTypeId(T: type) TypeId {
    return comptime std.hash.Fnv1a_64.hash(@typeName(T));
}

pub var registry: Registry = undefined;
pub var w = &registry;
pub fn init(allocator: std.mem.Allocator) void {
    registry = Registry.init(allocator);
}

pub fn clear() void {
    registry.deinit();
    registry = Registry.init(registry.allocator);
}

pub fn deinit() void {
    registry.deinit();
}
