const std = @import("std");
const firefly = @import("api.zig").firefly;

const trait = std.meta.trait;
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

const AspectGroup = firefly.utils.aspect.AspectGroup;
const EventDispatch = firefly.utils.event.EventDispatch;
const aspect = firefly.utils.aspect;
const Aspect = aspect.Aspect;
const DynArray = firefly.utils.dynarray.DynArray;
const BitSet = firefly.utils.bitset.BitSet;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;
const NO_NAME = firefly.utils.NO_NAME;
const String = firefly.utils.String;

pub const CompEventType = enum {
    NONE,
    Created,
    Activated,
    Deactivated,
    Disposing,
};

const CompTypeDeinit = struct {
    deinit: *const fn () void,
};

pub const CompPoolPtr = struct {
    address: usize = undefined,
    aspect: *Aspect = undefined,

    pub fn cast(self: CompPoolPtr, comptime T: type) *T {
        if (T.typeCheck(self.aspect)) {
            return @as(*T, @ptrFromInt(self.address));
        } else {
            std.debug.panic("Type mismatch: Expected {s}, but got <unknown>!", .{@typeName(*T)});
        }
    }
};

pub const ComponentId = struct {
    cTypePtr: CompPoolPtr = undefined,
    cIndex: usize = undefined,
};

// component global variables and state
var INIT = false;
var DEINIT_REFERENCES: std.ArrayList(CompTypeDeinit) = undefined;
var COMPONENT_ASPECT_GROUP: *AspectGroup = undefined;
var COMPONENT_POOL_POINTER: DynArray(CompPoolPtr) = undefined;

pub fn componentInit(allocator: Allocator) !void {
    defer INIT = true;
    if (INIT) {
        return;
    }
    DEINIT_REFERENCES = std.ArrayList(CompTypeDeinit).init(allocator);
    COMPONENT_ASPECT_GROUP = try aspect.newAspectGroup("COMPONENT_ASPECT_GROUP");
}

pub fn componentDeinit() void {
    defer INIT = false;
    if (!INIT) {
        return;
    }
    for (DEINIT_REFERENCES.items) |ref| {
        ref.deinit();
    }
    DEINIT_REFERENCES.deinit();
    DEINIT_REFERENCES = undefined;
    COMPONENT_ASPECT_GROUP = undefined;
}

pub fn CompLifecycleEvent(comptime T: type) type {
    return struct {
        const Self = @This();
        const c_type = T;

        event_type: CompEventType = CompEventType.NONE,
        c_index: usize = UNDEF_INDEX,

        fn create() Self {
            return Self{};
        }

        pub fn getCType(self: *Self) T {
            _ = self;
            return c_type;
        }
    };
}

pub fn ComponentPool(comptime T: type) type {
    return struct {
        const Self = @This();
        pub var typeErasedPtr: CompPoolPtr = undefined;

        // ensure type based singleton
        var initialized = false;
        var selfRef: Self = undefined;

        // internal state
        var items: DynArray(T) = undefined;
        // ... mappings
        var active_mapping: BitSet = undefined;
        var name_mapping: ?StringHashMap(usize) = null;
        // ... events
        const e_type = CompLifecycleEvent(T);
        var event: ?CompLifecycleEvent(T) = null;
        //var eventDispatch: ?EventDispatch(CompLifecycleEvent(T)) = null;

        // external state
        c_aspect: *Aspect = undefined,

        pub fn init(comptime emptyValue: T, withNameMapping: bool, withEventPropagation: bool) *Self {
            if (initialized) {
                return &selfRef;
            }

            errdefer deinit();
            defer {
                DEINIT_REFERENCES.append(CompTypeDeinit{ .deinit = T.deinit }) catch @panic("Register Deinit failed");
                initialized = true;
            }

            items = DynArray(T).init(firefly.COMPONENT_ALLOC, emptyValue) catch @panic("Init items failed");
            active_mapping = BitSet.initEmpty(firefly.COMPONENT_ALLOC, 64) catch @panic("Init active mapping failed");
            selfRef = Self{
                .c_aspect = COMPONENT_ASPECT_GROUP.getAspect(@typeName(T)),
            };

            typeErasedPtr = CompPoolPtr{
                .aspect = selfRef.c_aspect,
                .address = @intFromPtr(&selfRef),
            };

            if (withNameMapping) {
                name_mapping = StringHashMap(usize).init(firefly.COMPONENT_ALLOC);
            }

            if (withEventPropagation) {
                event = CompLifecycleEvent(T).create();
                EventDispatch(e_type).init(firefly.COMPONENT_ALLOC);
            }

            return &selfRef;
        }

        pub fn typeCheck(a: *Aspect) bool {
            if (!initialized)
                return false;

            return selfRef.c_aspect.index == a.index;
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            defer initialized = false;
            if (!initialized)
                return;

            self.c_aspect = undefined;
            items.deinit();
            active_mapping.deinit();

            if (name_mapping) |*nm|
                nm.deinit();

            if (event) |_| {
                EventDispatch(CompLifecycleEvent(T)).deinit();
                event = undefined;
            }
        }

        pub fn count(_: *Self) usize {
            return items.slots.count();
        }

        pub fn activeCount(_: *Self) usize {
            return active_mapping.count();
        }

        pub fn subscribe(_: *Self, listener: *const fn (CompLifecycleEvent(T)) void) void {
            if (event) |_| {
                EventDispatch(e_type).register(listener);
            }
        }

        pub fn unsubscribe(_: *Self, listener: *const fn (CompLifecycleEvent(T)) void) void {
            if (event) |_| {
                EventDispatch(e_type).unregister(listener);
            }
        }

        pub fn reg(_: *Self, c: T) *T {
            checkComponentTrait(c);

            var index = items.add(c);
            var result = items.get(index);
            result.index = index;

            if (name_mapping) |*nm| {
                if (!std.mem.eql(u8, c.name, NO_NAME))
                    nm.put(result.name, index) catch unreachable;
            }

            notify(CompEventType.Created, index);
            return result;
        }

        pub fn get(_: *Self, index: usize) *T {
            return items.get(index);
        }

        pub fn getByName(_: *Self, name: String) ?*T {
            if (name_mapping) |*nm| {
                if (nm.get(name)) |index| {
                    return items.get(index);
                }
            }
            return null;
        }

        pub fn activate(_: *Self, index: usize, a: bool) void {
            active_mapping.setValue(index, a);
            notify(if (a) CompEventType.Activated else CompEventType.Deactivated, index);
        }

        pub fn clearAll(_: *Self) void {
            var i: usize = 0;
            while (items.slots.nextSetBit(i)) |next| {
                clear(i);
                i = next + 1;
            }
        }

        pub fn clear(_: *Self, index: usize) void {
            notify(CompEventType.Disposing, index);
            active_mapping.setValue(index, false);
            items.reset(index);
        }

        pub fn processAllActive(_: *Self, f: *const fn (*T) void) void {
            var i: usize = 0;
            while (active_mapping.nextSetBit(i)) |next| {
                f(items.get(i));
                i = next + 1;
            }
        }

        pub fn processBitSet(_: *Self, indices: *BitSet, f: *const fn (*T) void) void {
            var i: usize = 0;
            while (indices.nextSetBit(i)) |next| {
                f(items.get(i));
                i = next + 1;
            }
        }

        pub fn processIndexed(_: *Self, indices: []usize, f: *const fn (*T) void) void {
            for (indices) |i| {
                f(items.get(i));
            }
        }

        fn notify(event_type: CompEventType, index: usize) void {
            if (event) |*e| {
                // Test if copy here affects performance (but it thread safe?)
                var ce = e.*;
                ce.event_type = event_type;
                ce.c_index = index;
                EventDispatch(CompLifecycleEvent(T)).notify(ce);
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
