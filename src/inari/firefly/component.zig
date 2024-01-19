const std = @import("std");
const firefly = @import("firefly.zig");

const AspectGroup = firefly.utils.aspect.AspectGroup;
const aspect = firefly.utils.aspect;
const Aspect = aspect.Aspect;
const trait = std.meta.trait;
const Allocator = std.mem.Allocator;
const DynArray = firefly.utils.dynarray.DynArray;
const BitSet = firefly.utils.bitset.BitSet;

// component namespace variables and state
var INIT = false;
var POOL_REFERENCES: std.ArrayList(CompTypeInit) = undefined;
var COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;

pub const CompTypeInit = struct {
    deinit: *const fn () void,
};

pub const ComponentId = struct {
    cType: type = undefined,
    index: usize = undefined,
};

pub fn componentInit(allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    POOL_REFERENCES = std.ArrayList(CompTypeInit).init(allocator);
    COMPONENT_ASPECT_GROUP = try aspect.newAspectGroup("COMPONENT_ASPECT_GROUP");
}

pub fn componentDeinit() void {
    defer INIT = false;
    if (!INIT) {
        return;
    }
    for (POOL_REFERENCES.items) |ref| {
        ref.deinit();
    }
    POOL_REFERENCES.deinit();
    POOL_REFERENCES = undefined;
    COMPONENT_ASPECT_GROUP = undefined;
}

pub fn registerComponentType(comptime cType: anytype) void {
    comptime {
        if (!trait.isPtrTo(.Type)(@TypeOf(cType))) @compileError("Expects cType to be pointer type.");
        if (!trait.hasDecls(cType.*, .{ "pool", "null_value", "deinit" }))
            @compileError("Expects component to have declared 'pool' and 'null_value' and fn 'deinit'.");
    }
    cType.*.pool.init(cType.*.null_value);
    POOL_REFERENCES.append(CompTypeInit{ .deinit = cType.*.deinit }) catch unreachable;
}

pub fn ComponentPool(comptime T: type) type {
    return struct {
        const Self = @This();
        // ensure type based singleton
        var initialized = false;

        pub var c_aspect: *Aspect = undefined;
        pub var items: DynArray(T) = undefined;
        pub var active_items: BitSet = undefined;

        pub fn init(comptime emptyValue: T) void {
            if (initialized) {
                return;
            }

            defer initialized = true;
            errdefer deinit();

            c_aspect = COMPONENT_ASPECT_GROUP.getAspect(@typeName(T));
            items = DynArray(T).init(firefly.COMPONENT_ALLOC, emptyValue) catch unreachable;
            active_items = BitSet.initEmpty(firefly.COMPONENT_ALLOC, 64) catch unreachable;
        }

        /// Release all allocated memory.
        pub fn deinit() void {
            defer initialized = false;
            if (initialized) {
                c_aspect = undefined;
                items.deinit();
                active_items.deinit();
            }
        }

        pub fn count() usize {
            return items.slots.count();
        }

        pub fn activeCount() usize {
            return active_items.count();
        }

        pub fn reg(c: T) *T {
            checkComponentTrait(c);
            var index = items.add(c);
            var result = items.get(index);
            result.index = index;
            return result;
        }

        pub fn regActive(c: T) *T {
            var result = reg(c);
            activate(result.index);
            return result;
        }

        pub fn activate(index: usize) void {
            active_items.set(index);
        }

        pub fn deactivate(index: usize) void {
            active_items.setValue(index, false);
        }

        pub fn clearAll() void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(index: usize) void {
            active_items.setValue(index, false);
            items.reset(index);
        }

        pub fn processAllActive(comptime f: fn (c: *T) void) void {
            var i: usize = 0;
            while (active_items.nextSetBit(i)) |next| {
                f(&items[next]);
                i = next + 1;
            }
        }

        pub fn processBitSet(indices: *BitSet, comptime f: fn (c: *T) void) void {
            var i: usize = 0;
            while (indices.nextSetBit(i)) |next| {
                f(&items[next]);
                i = next + 1;
            }
        }

        pub fn processIndexed(indices: []usize, comptime f: fn (c: *T) void) void {
            for (indices) |index| {
                f(&items[index]);
            }
        }

        fn checkComponentTrait(c: T) void {
            comptime {
                if (!trait.is(.Struct)(@TypeOf(c))) @compileError("Expects component is a struct.");
                if (!trait.hasField("index")(@TypeOf(c))) @compileError("Expects component to have field 'index'.");
                if (!trait.hasFn("clear")(@TypeOf(c))) @compileError("Expects component to have fn 'clear'.");
            }
        }
    };
}
