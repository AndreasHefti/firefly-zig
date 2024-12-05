const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;
const api = firefly.api;
const physics = firefly.physics;

// const Vector2i = firefly.utils.Vector2i;
// const Vector2f = firefly.utils.Vector2f;
// const CInt = firefly.utils.CInt;
const Index = firefly.utils.Index;
const String = firefly.utils.String;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// Behavior init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    // register components
    api.Component.register(BehaviorNode, "BehaviorNode");
    api.Entity.registerComponent(EBehavior, "EBehavior");
    api.System.register(BehaviorSystem);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Behavior API
//////////////////////////////////////////////////////////////

// this gives a dependency loop error, don't know why!?
//pub const BehaviorFunction = *const fn (self: *BehaviorNode, ctx: *api.CallContext) void;

pub const BehaviorNode = struct {
    pub const Component = api.Component.Mixin(BehaviorNode);
    pub const Naming = api.Component.NameMappingMixin(BehaviorNode);

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    _update: *const fn (self: *BehaviorNode, ctx: *api.CallContext) void,
    children: ?utils.DynIndexArray = null,

    threshold: ?u8 = null,

    pub fn destruct(self: *BehaviorNode) void {
        if (self.children) |*c|
            c.deinit();
        self.children = null;
        self.threshold = null;
    }

    pub fn withChild(self: *BehaviorNode, c: BehaviorNode) *BehaviorNode {
        if (self.children == null)
            self.children = utils.DynIndexArray.new(api.COMPONENT_ALLOC, 3);

        self.children.?.set(BehaviorNode.Component.new(c));
        return self;
    }

    pub fn update(self: *BehaviorNode, ctx: *api.CallContext) void {
        self._update(self, ctx);
    }
};

pub fn sequence(self: *BehaviorNode, ctx: *api.CallContext) void {
    if (self.children) |*refs| {
        for (0..refs.size_pointer) |i| {
            var child = BehaviorNode.Component.byId(refs.get(i));
            child.update(ctx);
            if (ctx.result == api.ActionResult.Running or ctx.result == api.ActionResult.Failure)
                return;
        }
    }
}

pub fn fallback(self: *BehaviorNode, ctx: *api.CallContext) void {
    if (self.children) |*refs| {
        for (0..refs.size_pointer) |i| {
            var child = BehaviorNode.Component.byId(refs.get(i));
            child.update(ctx);
            if (ctx.result == api.ActionResult.Running or ctx.result == api.ActionResult.Success)
                return;
        }
    }
}

pub fn parallel(self: *BehaviorNode, ctx: *api.CallContext) void {
    if (self.children) |*refs| {
        var num: u8 = 0;
        for (0..refs.size_pointer) |i| {
            var child = BehaviorNode.Component.byId(refs.get(i));
            child.update(ctx);
            if (ctx.result == api.ActionResult.Success)
                num += 1;
            if (num >= self.threshold.? orelse refs.size_pointer - 1)
                return;
        }
    }
    ctx.result = api.ActionResult.Failure;
}

pub const BehaviorTreeBuilder = struct {
    stack: utils.DynIndexArray,

    pub fn newTreeWithSequence(name: String) *BehaviorTreeBuilder {
        return newTree(.{
            .name = name,
            ._update = sequence,
        });
    }

    pub fn newTree(root: BehaviorNode) *BehaviorTreeBuilder {
        var tree = api.ALLOC.create(BehaviorTreeBuilder) catch unreachable;
        tree.stack = utils.DynIndexArray.new(api.ALLOC, 10);
        tree.stack.add(BehaviorNode.Component.new(root));
        return tree;
    }

    pub fn addSequence(self: *BehaviorTreeBuilder, name: ?String) *BehaviorTreeBuilder {
        const child_id = BehaviorNode.Component.new(.{
            ._update = sequence,
            .name = name,
        });
        const parent_id = self.stack.get(self.stack.size_pointer - 1);
        connect(parent_id, child_id);
        self.stack.add(child_id);
        return self;
    }

    pub fn addFallback(self: *BehaviorTreeBuilder, name: ?String) *BehaviorTreeBuilder {
        const child_id = BehaviorNode.Component.new(.{
            ._update = fallback,
            .name = name,
        });
        const parent_id = self.stack.get(self.stack.size_pointer - 1);
        connect(parent_id, child_id);
        self.stack.add(child_id);
        return self;
    }

    pub fn addParallel(self: *BehaviorTreeBuilder, name: ?String, threshold: ?u8) *BehaviorTreeBuilder {
        const child_id = BehaviorNode.Component.new(.{
            ._update = fallback,
            .name = name,
            .threshold = threshold,
        });
        const parent_id = self.stack.get(self.stack.size_pointer - 1);
        connect(parent_id, child_id);
        self.stack.add(child_id);
        return self;
    }

    pub fn addAction(self: *BehaviorTreeBuilder, action_function: *const fn (self: *BehaviorNode, ctx: *api.CallContext) void, name: ?String) *BehaviorTreeBuilder {
        const child_id = BehaviorNode.Component.new(.{
            ._update = action_function,
            .name = name,
        });
        const parent_id = self.stack.get(self.stack.size_pointer - 1);
        connect(parent_id, child_id);
        return self;
    }

    pub fn addChild(self: *BehaviorTreeBuilder, child: BehaviorNode) *BehaviorTreeBuilder {
        const child_id = BehaviorNode.Component.new(child);
        const parent_id = self.stack.get(self.stack.size_pointer - 1);
        connect(parent_id, child_id);
        self.stack.add(child_id);
        return self;
    }

    pub fn connect(parent: Index, child: Index) void {
        var p = BehaviorNode.Component.byId(parent);
        if (p.children == null)
            p.children = utils.DynIndexArray.new(api.COMPONENT_ALLOC, 3);

        p.children.?.add(child);
    }

    pub fn addChildByName(parent_name: String, child_name: String) void {
        if (BehaviorNode.Naming.byName(parent_name)) |parent| {
            if (BehaviorNode.Naming.byName(child_name)) |child| {
                if (parent.children == null)
                    parent.children = utils.DynIndexArray.new(api.COMPONENT_ALLOC, 3);

                parent.children.?.add(child.id);
            }
        }
    }

    pub fn pop(self: *BehaviorTreeBuilder) *BehaviorTreeBuilder {
        self.stack.removeAt(self.stack.size_pointer - 1);
        return self;
    }

    pub fn build(self: *BehaviorTreeBuilder) usize {
        const root_id = self.stack.get(0);
        self.stack.deinit();
        api.ALLOC.destroy(self);
        return root_id;
    }
};

pub const EBehavior = struct {
    pub const Component = api.EntityComponentMixin(EBehavior);
    pub const CallContext = api.Component.CallContextMixin(EBehavior);

    id: Index = UNDEF_INDEX,

    root_node_id: Index,
    call_context: api.CallContext = undefined,
};

pub const BehaviorSystem = struct {
    pub const System = api.SystemMixin(BehaviorSystem);
    pub const EntityUpdate = api.EntityUpdateSystemMixin(BehaviorSystem);
    pub const accept = .{EBehavior};

    pub fn updateEntities(components: *utils.BitSet) void {
        var next = components.nextSetBit(0);
        while (next) |i| {
            next = components.nextSetBit(i + 1);
            var behavior = EBehavior.Component.byId(i);
            var root_node = BehaviorNode.Component.byId(i);
            root_node.update(&behavior.call_context);
        }
    }
};
