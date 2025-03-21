const std = @import("std");
const firefly = @import("../firefly.zig");
const utils = firefly.utils;

const Allocator = std.mem.Allocator;
const asset = @import("asset.zig");
const component = @import("component.zig");
const composite = @import("composite.zig");
const system = @import("system.zig");
const timer = @import("timer.zig");
const entity = @import("entity.zig");
const control = @import("control.zig");

const String = utils.String;
const CString = utils.CString;
const String0 = firefly.utils.String0;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const CInt = utils.CInt;
const CUInt = firefly.utils.CUInt;
const Float = utils.Float;
const PosF = utils.PosF;
const RectF = utils.RectF;
const Color = utils.Color;
const Vector2f = utils.Vector2f;
const Vector3f = utils.Vector3f;
const Vector4f = utils.Vector4f;
const StringBuffer = utils.StringBuffer;

const Aes256Gcm = std.crypto.aead.aes_gcm.Aes256Gcm;
const nonce: [Aes256Gcm.nonce_length]u8 = [_]u8{0x42} ** Aes256Gcm.nonce_length;

fn dummyDeinit() void {}

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const ERRORS = error{
    NO_ATTRIBUTES,
    ATTRIBUTE_NOT_FOUND,
    ENCRYPTION_KEY_LENGTH_MISMATCH,
};

pub const IOErrors = error{
    UNKNOWN_LOAD_ERROR,
    FILE_DOES_NOT_EXIST,
    LOAD_TEXTURE_ERROR,
    LOAD_SPRITE_SET_ERROR,
    LOAD_IMAGE_ERROR,
    LOAD_FONT_ERROR,
    LOAD_RENDER_TEXTURE_ERROR,
    LOAD_SHADER_ERROR,
    LOAD_SOUND_ERROR,
    LOAD_MUSIC_ERROR,
};

pub const RUN_ON = enum { RAYLIB, TEST };
pub const RUN_ON_SET: RUN_ON = RUN_ON.RAYLIB;

pub const InitContext = struct {
    component_allocator: Allocator,
    entity_allocator: Allocator,
    allocator: Allocator,
};

pub const BindingId = usize;

/// COMPONENT_ALLOC is used for component allocation. A component of specified type uses a
/// Register or Pool that grows as needed using this allocator. But never shrinks until the
/// component type is been de-initialized. This is done when the whole system de-initializes
pub var COMPONENT_ALLOC: Allocator = undefined;

/// ENTITY_ALLOC works the same way as COMPONENT_ALLOC and is used allocation of entity components
pub var ENTITY_ALLOC: Allocator = undefined;

/// ALLOC is a general purpose allocator that needs to be managed by the user
pub var ALLOC: Allocator = undefined;

/// The POOL_ALLOC allocator is an arena allocator that can be used for arbitrary data that needs
/// longer lifetime and is freed all at once at the de-initialization of the program.
/// Or you can free it at an defined point in program.
pub var POOL_ALLOC: Allocator = undefined;
var pool_alloc_arena: std.heap.ArenaAllocator = undefined;

pub fn freePoolAllocator() void {
    if (initialized) {
        if (!pool_alloc_arena.reset(.free_all))
            Logger.warn("Failed to free whole POOL_ALLOC", .{})
        else
            Logger.info("Successfully freed whole POOL_ALLOC", .{});
    }
}

/// LOAD_ALLOC is an arena allocator that can be used for arbitrary load tasks. It uses ALLOC as child allocator.
/// Practically one can reset it after a heavy load task has been done and memory is not used anymore.
/// The system de-initialization will free all memory when happened
pub var LOAD_ALLOC: Allocator = undefined;
var load_alloc_arena: std.heap.ArenaAllocator = undefined;

pub fn freeLoadAllocator() void {
    if (initialized) {
        if (load_alloc_arena.reset(.free_all))
            Logger.warn("Failed to free whole LOAD_ALLOC", .{})
        else
            Logger.info("Successfully freed whole LOAD_ALLOC", .{});
    }
}

pub var rendering: IRenderAPI() = undefined;
pub var window: IWindowAPI() = undefined;
pub var input: IInputAPI() = undefined;
pub var audio: IAudioAPI() = undefined;

pub const Asset = asset.Asset;
pub const Component = component;
pub const ComponentEvent = component.ComponentEvent;
pub const ComponentListener = component.ComponentListener;
pub const Condition = control.Condition;
pub const System = system.System;
pub const SystemMixin = system.SystemMixin;
pub const EntityUpdateSystemMixin = entity.EntityUpdateSystemMixin;
pub const Timer = timer;
pub const FrameScheduler = timer.FrameScheduler;
pub const Entity = entity.Entity;
pub const EntityComponentMixin = entity.EntityComponentMixin;
pub const EntityTypeCondition = entity.EntityTypeCondition;
pub const EMultiplier = entity.EMultiplier;
pub const Task = control.Task;
pub const Trigger = control.Trigger;
pub const Control = control.Control;
pub const EControl = control.EControl;
pub const VoidControl = control.VoidControl;
pub const Composite = composite.Composite;
pub const CompositeTaskRef = composite.CompositeTaskRef;
pub const CompositeLifeCycle = composite.CompositeLifeCycle;
pub const CompositeMixin = composite.CompositeMixin;
pub const State = control.State;
pub const StateEngine = control.StateEngine;
pub const EntityStateEngine = control.EntityStateEngine;
pub const EState = control.EState;
pub const StateSystem = control.StateSystem;
pub const EntityStateSystem = control.EntityStateSystem;

pub const ComponentAspectGroup = utils.AspectGroup("ComponentType");
pub const ComponentKind = ComponentAspectGroup.Kind;
pub const ComponentAspect = ComponentAspectGroup.Aspect;

pub const SubTypeAspectGroup = utils.AspectGroup("ComponentSubType");
pub const SubTypeKind = SubTypeAspectGroup.Kind;
pub const SubTypeAspect = SubTypeAspectGroup.Aspect;

pub const GroupAspectGroup = utils.AspectGroup("ComponentGroup");
pub const GroupKind = GroupAspectGroup.Kind;
pub const GroupAspect = GroupAspectGroup.Aspect;

pub const EComponentAspectGroup = utils.AspectGroup("EComponent");
pub const EComponentKind = EComponentAspectGroup.Kind;
pub const EComponentAspect = EComponentAspectGroup.Aspect;

pub const ActionResult = enum {
    Running,
    Success,
    Failure,
};

pub const CRef = struct {
    type: ComponentAspect,
    id: Index,
    is_valid: *const fn (Index) bool,
    activation: ?*const fn (Index, bool) void,
    dispose: ?*const fn (Index) void,
};

pub const DeinitFunction = *const fn () void;
pub const CallFunction = *const fn (*CallContext) void;
pub const CallPredicate = *const fn (*CallContext) bool;
pub const CRefCallback = *const fn (CRef, ?*CallContext) void;

//////////////////////////////////////////////////////////////
//// Initialization
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(context: InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    COMPONENT_ALLOC = context.component_allocator;
    ENTITY_ALLOC = context.entity_allocator;
    ALLOC = context.allocator;

    Logger.log_buffer = ALLOC.alloc(u8, 1000) catch |err| handleUnknownError(err);
    Logger.info("*** Starting Firefly Engine *** \n", .{});

    pool_alloc_arena = std.heap.ArenaAllocator.init(ALLOC);
    POOL_ALLOC = pool_alloc_arena.allocator();
    load_alloc_arena = std.heap.ArenaAllocator.init(ALLOC);
    LOAD_ALLOC = load_alloc_arena.allocator();

    UPDATE_EVENT_DISPATCHER = utils.EventDispatch(UpdateEvent).new(ALLOC);
    RENDER_EVENT_DISPATCHER = utils.EventDispatch(RenderEvent).new(ALLOC);
    VIEW_RENDER_EVENT_DISPATCHER = utils.EventDispatch(ViewRenderEvent).new(ALLOC);

    if (RUN_ON_SET == RUN_ON.RAYLIB) {
        rendering = try @import("raylib/rendering.zig").createRenderAPI();
        window = try @import("raylib/window.zig").createWindowAPI();
        input = try @import("raylib/input.zig").createInputAPI();
        audio = try @import("raylib/audio.zig").createInputAPI();
    } else {
        rendering = IRenderAPI().initDummy();
        window = IWindowAPI().initDummy();
        input = IInputAPI().initDummy();
        audio = IAudioAPI().initDummy();
    }

    NamePool.init();
    Component.init();
    Timer.init();
    system.init();
    entity.init();

    // register api based components and entity components
    Component.register(Attributes, "Attributes");
    Component.register(Entity, "Entity");
    Entity.registerComponent(EMultiplier, "EMultiplier");

    asset.init();
    control.init();
    composite.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    composite.deinit();
    asset.deinit();
    control.deinit();
    system.deinit();
    Component.deinit();
    entity.deinit();

    rendering.deinit();
    rendering = undefined;
    window.deinit();
    window = undefined;
    input.deinit();
    input = undefined;
    audio.deinit();
    audio = undefined;
    Timer.deinit();

    UPDATE_EVENT_DISPATCHER.deinit();
    RENDER_EVENT_DISPATCHER.deinit();
    VIEW_RENDER_EVENT_DISPATCHER.deinit();

    NamePool.deinit();

    pool_alloc_arena.deinit();
    load_alloc_arena.deinit();

    Logger.info("*** Firefly Engine stopped *** \n", .{});
    ALLOC.free(Logger.log_buffer);
}

//////////////////////////////////////////////////////////////
//// Generic API declaration and field names
//////////////////////////////////////////////////////////////

pub const FIELD_NAMES = struct {
    pub const COMPONENT_ID_FIELD: String = "id";
    pub const COMPONENT_NAME_FIELD: String = "name";

    pub const COMPONENT_GROUPS_FIELD: String = "groups";

    pub const CALL_CONTEXT_FIELD: String = "call_context";
    pub const ATTRIBUTE_ID_FIELD: String = "attributes_id";
    pub const ATTRIBUTE_INIT_FLAG_FIELD: String = "init_attributes";
};

pub const DECLARATION_NAMES = struct {
    pub const COMPONENT_MIXIN: String = "Component";
    pub const ACTIVATION_MIXIN: String = "Activation";
    pub const NAMING_MIXIN: String = "Naming";
    pub const SUBSCRIPTION_MIXIN: String = "Subscription";
    pub const CALL_CONTEXT_MIXIN: String = "CallContext";
    pub const ATTRIBUTE_MIXIN: String = "Attributes";
    pub const GROUPING_MIXIN: String = "Grouping";
    pub const CONTROL_MIXIN: String = "Control";
    pub const SUBTYPE_MIXIN: String = "Subtypes";

    pub const ENTITY_KIND_ACCEPT: String = "accept";
    pub const ENTITY_KIND_ACCEPT_FULL_ONLY: String = "accept_full_only";
    pub const ENTITY_KIND_DISMISS: String = "dismiss";

    pub const SYSTEM_ENTITY_UPDATE_MIXIN: String = "EntityUpdate";
    pub const SYSTEM_ENTITY_RENDERER_MIXIN: String = "EntityRenderer";
    pub const SYSTEM_COMPONENT_RENDERER_MIXIN: String = "ComponentRenderer";

    pub const SYSTEM_ENTITY_CONDITION: String = "entity_condition";
    pub const SYSTEM_COMPONENT_CONDITION: String = "componentCondition";
    pub const SYSTEM_COMPONENT_REGISTER_TYPE: String = "component_register_type";
};

pub const FUNCTION_NAMES = struct {
    pub const COMPONENT_TYPE_INIT_FUNCTION: String = "componentTypeInit";
    pub const COMPONENT_TYPE_DEINIT_FUNCTION: String = "componentTypeDeinit";
    pub const COMPONENT_CONSTRUCTOR_FUNCTION: String = "construct";
    pub const COMPONENT_DESTRUCTOR_FUNCTION: String = "destruct";
    pub const COMPONENT_ACTIVATION_FUNCTION: String = "activation";
    pub const COMPONENT_UPDATE_FUNCTION: String = "update";
    pub const COMPONENT_RESOLVE_FUNCTION: String = "resolve";
    pub const COMPONENT_REGISTER_FUNCTION: String = "register";
    pub const COMPONENT_CONTROLLED_TYPE_FUNCTION: String = "controlledComponentType";

    pub const ENTITY_CREATE_COMPONENT_FUNCTION: String = "createEComponent";
    pub const ENTITY_COMPONENT_TYPE_INIT_FUNCTION: String = "entityComponentTypeInit";
    pub const ENTITY_COMPONENT_TYPE_DEINIT_FUNCTION: String = "entityComponentTypeDeinit";
    pub const ENTITY_COMPONENT_UPDATE_FUNCTION: String = "updateEntities";

    pub const SYSTEM_INIT_FUNCTION: String = "systemInit";
    pub const SYSTEM_DEINIT_FUNCTION: String = "systemDeinit";
    pub const SYSTEM_ENTITY_REGISTRATION_FUNCTION: String = "entityRegistration";
    pub const SYSTEM_COMPONENT_REGISTRATION: String = "componentRegistration";
    pub const SYSTEM_RENDER_FUNCTION: String = "render";
    pub const SYSTEM_RENDER_VIEW_FUNCTION: String = "renderView";
    pub const SYSTEM_RENDER_COMPONENT_FUNCTION: String = "renderComponents";
};

//////////////////////////////////////////////////////////////
//// Convenient Functions
//////////////////////////////////////////////////////////////

pub fn loadFromFile(file_name: String, decryption_pwd: ?String) !String {
    const file_content = std.fs.cwd().readFileAlloc(
        LOAD_ALLOC,
        file_name,
        1000000,
    ) catch |err| {
        Logger.err("Failed to load file: {s} error: {s}", .{ file_name, @errorName(err) });
        return err;
    };

    if (decryption_pwd) |pwd| {
        if (pwd.len != 32)
            return ERRORS.ENCRYPTION_KEY_LENGTH_MISMATCH;

        return try decrypt(file_content, pwd[0..32].*, LOAD_ALLOC);
    }
    return file_content;
}

pub fn writeToFile(file_name: String, text: String, encryption_pwd: ?String) !void {
    const file: std.fs.File = std.fs.cwd().createFile(
        file_name,
        .{ .read = true },
    ) catch |err| {
        Logger.err("Failed to write to file: {s} error {s}", .{ file_name, @errorName(err) });
        return err;
    };

    defer file.close();

    var bytes: String = undefined;
    if (encryption_pwd) |pwd| {
        if (pwd.len != 32)
            return ERRORS.ENCRYPTION_KEY_LENGTH_MISMATCH;

        bytes = try encrypt(text, pwd[0..32].*, LOAD_ALLOC);
    } else {
        bytes = text;
    }

    try file.writeAll(bytes);
}

pub fn allocFloatArray(array: anytype) []Float {
    return firefly.api.POOL_ALLOC.dupe(Float, &array) catch |err| handleUnknownError(err);
}

pub fn allocVec2FArray(array: anytype) []const Vector2f {
    return firefly.api.POOL_ALLOC.dupe(Vector2f, &array) catch |err| handleUnknownError(err);
}

pub fn encrypt(text: String, password: [32]u8, allocator: Allocator) !String {
    const ad = "";
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    const cypher: []u8 = allocator.alloc(u8, text.len) catch |err| handleUnknownError(err);
    defer allocator.free(cypher);

    Aes256Gcm.encrypt(cypher, &tag, text, ad, nonce, password);

    const s: []const []const u8 = &[_]String{ cypher, &tag };
    return try std.mem.concat(allocator, u8, s);
}

pub fn decrypt(cypher: String, password: [32]u8, allocator: Allocator) !String {
    const ad = "";
    var tag: [Aes256Gcm.tag_length]u8 = undefined;
    const text: []u8 = allocator.alloc(u8, cypher.len - Aes256Gcm.tag_length) catch |err| handleUnknownError(err);
    std.mem.copyForwards(u8, &tag, cypher[cypher.len - Aes256Gcm.tag_length ..]);

    Aes256Gcm.decrypt(
        text,
        cypher[0 .. cypher.len - Aes256Gcm.tag_length],
        tag,
        ad,
        nonce,
        password,
    ) catch |err| {
        Logger.err("Failed to decrypt, error: {s}", .{@errorName(err)});
        return err;
    };
    return text;
}

/// Formats a String as usual in zig. The resulting String lives in NamePool / POOL_ALLOC
pub fn format(comptime fmt: String, args: anytype) String {
    const formatted = std.fmt.allocPrint(ALLOC, fmt, args) catch |err| handleUnknownError(err);
    defer ALLOC.free(formatted);
    return NamePool.alloc(formatted) orelse fmt;
}

/// Converts an integer Index to String value. The String lives in NamePool / POOL_ALLOC
pub fn indexToString(index: ?utils.Index) ?String {
    if (index) |i| {
        const str = std.fmt.allocPrint(ALLOC, "{d}", i) catch |err| {
            Logger.err("Failed to convert integer: {d} to String. Error: {s}", .{ index, @errorName(err) });
            return null;
        };

        defer POOL_ALLOC.free(str);
        return NamePool.alloc(str);
    }
    return null;
}

//////////////////////////////////////////////////////////////
//// Name Pool used for none constant Strings not living
//// in zigs data mem. These can be de-allocated by call
//// or will be freed all on package deinit
//////////////////////////////////////////////////////////////

pub const NamePool = struct {
    var names: std.BufSet = undefined;
    var S0_ALLOC: Allocator = undefined;
    var s0_alloc_arena: std.heap.ArenaAllocator = undefined;

    fn init() void {
        names = std.BufSet.init(POOL_ALLOC);
        s0_alloc_arena = std.heap.ArenaAllocator.init(ALLOC);
        S0_ALLOC = s0_alloc_arena.allocator();
    }

    pub fn deinit() void {
        names.deinit();
    }

    pub fn alloc(name: ?String) ?String {
        if (name) |n| {
            if (names.contains(n))
                return names.hash_map.getKey(n);

            names.insert(n) catch |err| handleUnknownError(err);
            //std.debug.print("************ NamePool names add: {s}\n", .{n});
            return names.hash_map.getKey(n);
        }
        return null;
    }

    pub fn alloc0(name: String) String0 {
        return S0_ALLOC.dupeZ(u8, name) catch |err| handleUnknownError(err);
    }

    pub fn free0(name: String0) void {
        S0_ALLOC.free(name);
    }

    pub fn freeS0Pool() void {
        s0_alloc_arena.reset(.free_all);
    }

    pub fn freeName(name: String) void {
        names.remove(name);
    }

    pub fn freeNames() void {
        names.deinit();
    }
};

//////////////////////////////////////////////////////////////
//// Global Logger and Error Handling
//////////////////////////////////////////////////////////////

pub inline fn handleUnknownError(err: anyerror) void {
    Logger.errWith("Unknown error happened:", .{}, err);
    @panic("Unknown error happened see logs");
}

pub inline fn handleError(err: anyerror, comptime msg: ?String, args: anytype) void {
    if (msg) |m|
        Logger.err(m, args);

    utils.panic(ALLOC, "Panic because of: {s}", .{@errorName(err)});
}

pub const Logger = struct {
    var log_buffer: []u8 = undefined;

    pub const API_TAG = "[Firefly]";

    const INFO_LOG_ON = true;
    const WARN_LOG_ON = true;
    const ERROR_LOG_ON = true;

    pub fn info(comptime msg: String, args: anytype) void {
        if (INFO_LOG_ON)
            std.log.info("{s} {s}", .{ API_TAG, _format(msg, args) });
    }

    pub fn warn(comptime msg: String, args: anytype) void {
        if (WARN_LOG_ON)
            std.log.warn("{s} {s}", .{ API_TAG, _format(msg, args) });
    }

    pub fn err(comptime msg: String, args: anytype) void {
        if (ERROR_LOG_ON)
            std.log.err("{s} {s}", .{ API_TAG, _format(msg, args) });
    }

    pub fn errWith(comptime msg: String, args: anytype, e: anyerror) void {
        if (ERROR_LOG_ON)
            std.log.err("{s} {s} : {s}", .{ API_TAG, @errorName(e), _format(msg, args) });
    }

    fn _format(comptime msg: String, args: anytype) String {
        return std.fmt.bufPrint(log_buffer, msg, args) catch |e| handleUnknownError(e);
    }
};

//////////////////////////////////////////////////////////////
//// Attributes
//////////////////////////////////////////////////////////////

pub const Attributes = struct {
    pub const Component = firefly.api.Component.Mixin(Attributes);
    pub const Naming = firefly.api.Component.NameMappingMixin(Attributes);
    pub const Global = struct {
        const IGNORE_ERROR: String = "IGNORE_ERROR";
    };

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    _dict: std.StringHashMap(String) = undefined,

    pub fn construct(self: *Attributes) void {
        //std.debug.print("** new attributes: {d}\n", .{self.id});
        self._dict = std.StringHashMap(String).init(ALLOC);
    }

    pub fn destruct(self: *Attributes) void {
        //std.debug.print("** clear attributes: {d}\n", .{self.id});
        self.clear();
        self._dict.deinit();
        self._dict = undefined;
    }

    pub fn newGet(name: ?String, attributes: anytype) *Attributes {
        var result = Attributes.Component.newAndGet(.{ .name = name });
        inline for (attributes) |v|
            result.set(v[0], v[1]);

        return result;
    }

    pub fn clear(self: *Attributes) void {
        var it = self._dict.iterator();
        while (it.next()) |e| {
            ALLOC.free(e.key_ptr.*);
            ALLOC.free(e.value_ptr.*);
        }

        self._dict.clearAndFree();
    }

    pub fn set(self: *Attributes, name: String, value: String) void {
        if (self._dict.contains(name))
            self.remove(name);

        self._dict.put(
            ALLOC.dupe(u8, name) catch |err| handleUnknownError(err),
            ALLOC.dupe(u8, value) catch |err| handleUnknownError(err),
        ) catch |err| handleUnknownError(err);
    }

    pub fn setAll(self: *Attributes, attributes: *Attributes) void {
        var it = attributes._dict.iterator();
        while (it.next()) |e|
            self.set(e.key_ptr.*, e.value_ptr.*);
    }

    pub fn get(self: *Attributes, name: String) ?String {
        return self._dict.get(name);
    }

    pub fn remove(self: *Attributes, name: String) void {
        if (self._dict.fetchRemove(name)) |kv| {
            ALLOC.free(kv.key);
            ALLOC.free(kv.value);
        }
    }

    pub fn format(
        self: Attributes,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Attributes({d}:{?s})[ ", .{ self.id, self.name });
        var it = self._dict.iterator();
        while (it.next()) |e| {
            try writer.print("{s}={s}, ", .{ e.key_ptr.*, e.value_ptr.* });
        }
        try writer.print("]", .{});
    }
};

//////////////////////////////////////////////////////////////
//// CallContext
//////////////////////////////////////////////////////////////

pub const CallContext = struct {
    caller_id: Index = UNDEF_INDEX,
    caller_name: ?String = null,

    id_1: Index = UNDEF_INDEX,
    id_2: Index = UNDEF_INDEX,
    id_3: Index = UNDEF_INDEX,
    id_4: Index = UNDEF_INDEX,

    attributes_id: ?Index = null,
    c_ref_callback: ?CRefCallback = null,
    result: ?ActionResult = null,

    pub fn new(caller_id: ?Index, attributes: anytype) CallContext {
        return CallContext{
            .caller_id = caller_id orelse UNDEF_INDEX,
            .attributes_id = Attributes.newGet(null, attributes).id,
        };
    }

    pub fn handleError(self: *CallContext, err: anyerror, comptime msg: String, args: anytype) void {
        self.result = .Failure;
        Logger.errWith(msg, args, err);
        if (self.boolean(Attributes.Global.IGNORE_ERROR))
            return;

        @panic("error");
    }

    pub fn optionalAttribute(self: *CallContext, name: String) ?String {
        if (self.getAttrs()) |attrs|
            return attrs.get(name);
        return null;
    }

    pub fn attribute(self: *CallContext, name: String) String {
        return optionalAttribute(self, name) orelse miss(name);
    }

    pub fn optionalString(self: *CallContext, name: String) ?String {
        return utils.parseName(self.optionalAttribute(name));
    }

    pub fn string(self: *CallContext, name: String) String {
        return optionalString(self, name) orelse miss(name);
    }

    pub fn boolean(self: *CallContext, name: String) bool {
        return utils.parseBoolean(self.optionalAttribute(name) orelse return false);
    }

    pub fn optionalRectF(self: *CallContext, name: String) ?RectF {
        return utils.parseRectF(self.attribute(name));
    }

    pub fn rectF(self: *CallContext, name: String) RectF {
        return optionalRectF(self, name) orelse miss(name);
    }

    pub fn properties(self: *CallContext, name: String) utils.StringPropertyIterator {
        return utils.StringPropertyIterator.new(attribute(self, name));
    }

    inline fn miss(name: String) void {
        std.debug.panic("No attribute with name: {s}", .{name});
    }

    inline fn getAttrs(self: *CallContext) ?*Attributes {
        if (self.attributes_id) |id|
            return Attributes.Component.byId(id);
        return null;
    }

    pub fn deinit(self: *CallContext) void {
        if (self.attributes_id) |aid|
            Attributes.Component.dispose(aid);
        self.attributes_id = null;
    }

    pub fn format(
        self: CallContext,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("CallContext({d}:{s})[\n", .{ utils.IndexFormatter{ .index = self.caller_id }, self.caller_name orelse "-" });
        if (self.id_1 != UNDEF_INDEX)
            try writer.print("  id_1: {d}\n", .{self.id_1});
        if (self.id_1 != UNDEF_INDEX)
            try writer.print("  id_2: {d}\n", .{self.id_2});
        if (self.id_1 != UNDEF_INDEX)
            try writer.print("  id_3: {d}\n", .{self.id_3});
        if (self.id_1 != UNDEF_INDEX)
            try writer.print("  id_4: {d}\n", .{self.id_4});
        if (self.result) |r|
            try writer.print("  result: {s}\n", .{@tagName(r)});
        if (self.attributes_id) |aid|
            try writer.print("  {any}\n", .{Attributes.Component.byId(aid)});

        try writer.print("]", .{});
    }
};

//////////////////////////////////////////////////////////////
//// Update Event and Render Event declarations
//////////////////////////////////////////////////////////////

var UPDATE_EVENT_DISPATCHER: utils.EventDispatch(UpdateEvent) = undefined;
var RENDER_EVENT_DISPATCHER: utils.EventDispatch(RenderEvent) = undefined;
var VIEW_RENDER_EVENT_DISPATCHER: utils.EventDispatch(ViewRenderEvent) = undefined;

pub const UpdateEvent = struct {};
pub const UpdateListener = *const fn (UpdateEvent) void;
pub const RenderEventType = enum {
    RENDER,
    POST_RENDER,
};
pub const RenderEvent = struct { type: RenderEventType };
pub const RenderListener = *const fn (RenderEvent) void;
pub const ViewRenderEvent = struct {
    view_id: ?Index = null,
    layer_id: ?Index = null,
    projection: ?*Projection = null,
};
pub const ViewRenderListener = *const fn (ViewRenderEvent) void;

pub inline fn subscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeUpdateAt(index: usize, listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.register(index, listener);
}

pub inline fn unsubscribeUpdate(listener: UpdateListener) void {
    UPDATE_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn subscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeRenderAt(index: usize, listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.registerInsert(index, listener);
}

pub inline fn unsubscribeRender(listener: RenderListener) void {
    RENDER_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn subscribeViewRender(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.register(listener);
}

pub inline fn subscribeViewRenderAt(index: usize, listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.registerInsert(index, listener);
}

pub inline fn unsubscribeViewRender(listener: ViewRenderListener) void {
    VIEW_RENDER_EVENT_DISPATCHER.unregister(listener);
}

pub inline fn update(event: UpdateEvent) void {
    UPDATE_EVENT_DISPATCHER.notify(event);
}

pub inline fn render(event: RenderEvent) void {
    RENDER_EVENT_DISPATCHER.notify(event);
}

pub inline fn renderView(event: ViewRenderEvent) void {
    VIEW_RENDER_EVENT_DISPATCHER.notify(event);
}

//////////////////////////////////////////////////////////////
//// Graphics API declarations
//////////////////////////////////////////////////////////////
pub const BlendMode = enum(CInt) {
    /// Blend textures considering alpha (default)
    ALPHA = 0,
    /// Blend textures adding colors
    ADDITIVE = 1,
    /// Blend textures multiplying colors
    MULTIPLIED = 2,
    /// Blend textures adding colors (alternative)
    ADD_COLORS = 3,
    /// Blend textures subtracting colors (alternative)
    SUBTRACT_COLORS = 4,
    /// Blend premultiplied textures considering alpha
    ALPHA_PREMULTIPLY = 5,
    /// Blend textures using custom src/dst factors (use rlSetBlendFactors())
    CUSTOM = 6,
    /// Blend textures using custom rgb/alpha separate src/dst factors (use rlSetBlendFactorsSeparate())
    CUSTOM_SEPARATE = 7,

    pub fn format(
        self: BlendMode,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.writeAll(switch (self) {
            .ALPHA => "ALPHA",
            .ADDITIVE => "ADDITIVE",
            .MULTIPLIED => "MULTIPLIED",
            .ADD_COLORS => "ADD_COLORS",
            .SUBTRACT_COLORS => "SUBTRACT_COLORS",
            .ALPHA_PREMULTIPLY => "ALPHA_PREMULTIPLY",
            .CUSTOM => "CUSTOM",
            .CUSTOM_SEPARATE => "CUSTOM_SEPARATE",
        });
    }
};

// Texture parameters: filter mode
// NOTE 1: Filtering considers mipmaps if available in the texture
// NOTE 2: Filter is accordingly set for minification and magnification
pub const TextureFilter = enum(CInt) {
    TEXTURE_FILTER_POINT = 0, // No filter, just pixel approximation
    TEXTURE_FILTER_BILINEAR = 1, // Linear filtering
    TEXTURE_FILTER_TRILINEAR = 2, // Trilinear filtering (linear with mipmaps)
    TEXTURE_FILTER_ANISOTROPIC_4X = 3, // Anisotropic filtering 4x
    TEXTURE_FILTER_ANISOTROPIC_8X = 4, // Anisotropic filtering 8x
    TEXTURE_FILTER_ANISOTROPIC_16X = 5, // Anisotropic filtering 16x
};

// Texture parameters: wrap mode
pub const TextureWrap = enum(CInt) {
    TEXTURE_WRAP_REPEAT = 0, // Repeats texture in tiled mode
    TEXTURE_WRAP_CLAMP = 1, // Clamps texture to edge pixel in tiled mode
    TEXTURE_WRAP_MIRROR_REPEAT = 2, // Mirrors and repeats the texture in tiled mode
    TEXTURE_WRAP_MIRROR_CLAMP = 3, // Mirrors and clamps to border the texture in tiled mode
};

pub const ShapeType = enum {
    POINT,
    LINE,
    RECTANGLE,
    CIRCLE,
    ARC,
    ELLIPSE,
    TRIANGLE,
};

pub const Projection = struct {
    clear_color: ?Color = .{ 0, 0, 0, 255 },
    position: PosF = .{ 0, 0 },
    width: Float = 0,
    height: Float = 0,
    pivot: PosF = .{ 0, 0 },
    zoom: Float = 1,
    rotation: Float = 0,
    flip_x: bool = false,
    flip_y: bool = false,

    pub fn format(
        self: Projection,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Projection[ clear_color:{any}, position:{any}, w:{any}, h{any}, pivot:{any}, zoom:{d}, rot:{d} flip_h:{any}, flip_v:{any} ]",
            self,
        );
    }
};

pub const TextureBinding = struct {
    id: BindingId,
    width: CInt = 0,
    height: CInt = 0,

    pub fn format(
        self: TextureBinding,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "TextureBinding[ id:{any}, width:{any}, height:{any} ]",
            self,
        );
    }
};

pub const RenderTextureBinding = struct {
    id: BindingId,
    width: CInt = 0,
    height: CInt = 0,

    pub fn format(
        self: RenderTextureBinding,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "RenderTextureBinding[ bind:{d}, w:{d}, h:{d} ]",
            self,
        );
    }
};

pub const ShaderBinding = struct {
    id: BindingId,

    _apply_call: ?*const fn (self: ShaderBinding) void = null,
    _set_uniform_float: *const fn (BindingId, String, Float) bool,
    _set_uniform_vec2: *const fn (BindingId, String, Vector2f) bool,
    _set_uniform_vec3: *const fn (BindingId, String, Vector3f) bool,
    _set_uniform_vec4: *const fn (BindingId, String, Vector4f) bool,
    _set_uniform_texture: *const fn (BindingId, String, BindingId) bool,
};

pub const ImageBinding = struct {
    id: BindingId,
    data: ?*anyopaque,
    width: CInt,
    height: CInt,
    mipmaps: CInt,
    format: CInt,

    get_color_at: *const fn (BindingId, CInt, CInt) ?Color,
    set_color_at: *const fn (BindingId, CInt, CInt, Color) void,
};

pub fn IRenderAPI() type {
    return struct {
        const Self = @This();

        setRenderBatch: *const fn (
            buffer_number: ?CInt,
            max_buffer_elements: ?CInt,
        ) void = undefined,

        /// Set rendering offset
        setOffset: *const fn (Vector2f) void = undefined,
        /// Adds given offset to actual offset of the rendering engine
        addOffset: *const fn (Vector2f) void = undefined,

        /// Loads image data from file system and create new texture data loaded into GPU
        /// @param textureData The texture DAO. Sets binding, width and height to the DAO
        loadTexture: *const fn (resource: String, is_mipmap: bool, filter: TextureFilter, wrap: TextureWrap) IOErrors!TextureBinding = undefined,
        /// Disposes the texture with given texture binding id from GPU memory
        /// @param textureId binding identifier of the texture to dispose.
        disposeTexture: *const fn (BindingId) void = undefined,

        loadImageFromTexture: *const fn (BindingId) IOErrors!ImageBinding = undefined,
        loadImageRegionFromTexture: *const fn (BindingId, RectF) IOErrors!ImageBinding = undefined,
        loadImageFromFile: *const fn (String) IOErrors!ImageBinding = undefined,
        disposeImage: *const fn (BindingId) void = undefined,

        loadFont: *const fn (resource: String, size: ?CInt, char_num: ?CInt, code_points: ?CInt) IOErrors!BindingId = undefined,
        disposeFont: *const fn (BindingId) void = undefined,

        createRenderTexture: *const fn (projection: *Projection) IOErrors!RenderTextureBinding = undefined,
        disposeRenderTexture: *const fn (BindingId) void = undefined,
        /// create new shader from given shader data and load it to GPU
        createShader: *const fn (vertex_shader: ?String, fragment_shade: ?String, file: bool) IOErrors!ShaderBinding = undefined,
        /// Dispose the shader with the given binding identifier (shaderId) from GPU
        /// @param shaderId identifier of the shader to dispose.
        disposeShader: *const fn (BindingId) void = undefined,
        /// Put the specified shader as active shader to the active shader stack
        /// @param shaderId The instance identifier of the shader.
        putShaderStack: *const fn (BindingId) void = undefined,
        /// Pops the current active shader from the active shader stack and makes new last shader from the stack the new
        /// active shader or, if the stack is empty, set the default shader
        popShaderStack: *const fn () void = undefined,
        /// Clears the shader stack and resets the default shader as active shader
        clearShaderStack: *const fn () void = undefined,

        showFPS: *const fn (pos: Vector2f) void = undefined,

        bindTexture: *const fn (String, BindingId) void = undefined,
        /// Start rendering to the given RenderTextureData or to the screen if no binding index is given
        /// Uses Projection to update camera projection and clear target before start rendering
        startRendering: *const fn (texture_id: ?BindingId, projection: *Projection) void = undefined,
        /// This renders a given RenderTextureData (BindingId) to the actual render target that can be
        /// rendering texture or the screen
        renderTexture: *const fn (
            texture_id: BindingId,
            position: PosF,
            pivot: PosF,
            scale: PosF,
            rotation: Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
            flip_x: bool,
            flip_y: bool,
        ) void = undefined,

        renderSprite: *const fn (
            texture_id: BindingId,
            texture_bounds: RectF,
            position: PosF,
            pivot: ?PosF,
            scale: ?PosF,
            rotation: ?Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
            multiplier: ?[]const PosF,
        ) void = undefined,

        renderShape: *const fn (
            shape_type: ShapeType,
            vertices: []Float,
            fill: bool,
            thickness: ?Float,
            offset: PosF,
            color: Color,
            blend_mode: ?BlendMode,
            pivot: ?PosF,
            scale: ?PosF,
            rotation: ?Float,
            color1: ?Color,
            color2: ?Color,
            color3: ?Color,
        ) void = undefined,

        renderText: *const fn (
            font_id: ?BindingId,
            text: String0,
            position: PosF,
            pivot: ?PosF,
            rotation: ?Float,
            size: ?Float,
            char_spacing: ?Float,
            line_spacing: ?Float,
            tint_color: ?Color,
            blend_mode: ?BlendMode,
        ) void = undefined,

        /// This is called form the firefly API to notify the end of rendering for the actual render target (RenderTextureData).
        /// switches back to screen rendering
        endRendering: *const fn () void = undefined,

        printDebug: *const fn (*StringBuffer) void = undefined,

        deinit: DeinitFunction = undefined,

        pub fn init(initImpl: *const fn (*IRenderAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }

        pub inline fn renderShapeMin(
            self: *Self,
            shape_type: ShapeType,
            vertices: []Float,
            fill: bool,
            thickness: ?Float,
            offset: PosF,
            color: Color,
        ) void {
            self.renderShape(shape_type, vertices, fill, thickness, offset, color, null, null, null, null, null, null, null);
        }
    };
}

pub const WindowFlag = enum(CUInt) {
    FLAG_VSYNC_HINT = 0x00000040, // Set to try enabling V-Sync on GPU
    FLAG_FULLSCREEN_MODE = 0x00000002, // Set to run program in fullscreen
    FLAG_WINDOW_RESIZABLE = 0x00000004, // Set to allow resizable window
    FLAG_WINDOW_UNDECORATED = 0x00000008, // Set to disable window decoration (frame and buttons)
    FLAG_WINDOW_HIDDEN = 0x00000080, // Set to hide window
    FLAG_WINDOW_MINIMIZED = 0x00000200, // Set to minimize window (iconify)
    FLAG_WINDOW_MAXIMIZED = 0x00000400, // Set to maximize window (expanded to monitor)
    FLAG_WINDOW_UNFOCUSED = 0x00000800, // Set to window non focused
    FLAG_WINDOW_TOPMOST = 0x00001000, // Set to window always on top
    FLAG_WINDOW_ALWAYS_RUN = 0x00000100, // Set to allow windows running while minimized
    FLAG_WINDOW_TRANSPARENT = 0x00000010, // Set to allow transparent framebuffer
    FLAG_WINDOW_HIGHDPI = 0x00002000, // Set to support HighDPI
    FLAG_WINDOW_MOUSE_PASSTHROUGH = 0x00004000, // Set to support mouse passthrough, only supported when FLAG_WINDOW_UNDECORATED
    FLAG_BORDERLESS_WINDOWED_MODE = 0x00008000, // Set to run program in borderless windowed mode
    FLAG_MSAA_4X_HINT = 0x00000020, // Set to try enabling MSAA 4X
    FLAG_INTERLACED_HINT = 0x00010000, // Set to try enabling interlaced video format (for V3D)
};

pub const WindowData = struct {
    width: CInt,
    height: CInt,
    fps: CInt,
    show_fps: bool = false,
    title: String,
    icon: ?String = null,
    flags: ?[]const WindowFlag = null,
};

pub fn IWindowAPI() type {
    return struct {
        const Self = @This();

        getCurrentMonitor: *const fn () CInt = undefined,
        getMonitorWidth: *const fn (CInt) CInt = undefined,
        getMonitorHeight: *const fn (CInt) CInt = undefined,

        openWindow: *const fn (WindowData) void = undefined,
        isWindowReady: *const fn () bool = undefined,
        getWindowData: *const fn () *WindowData = undefined,
        closeWindow: *const fn () void = undefined,

        hasWindowClosed: *const fn () bool = undefined,
        isWindowResized: *const fn () bool = undefined,
        isWindowFullscreen: *const fn () bool = undefined,
        isWindowHidden: *const fn () bool = undefined,
        isWindowMinimized: *const fn () bool = undefined,
        isWindowMaximized: *const fn () bool = undefined,
        isWindowFocused: *const fn () bool = undefined,
        isWindowState: *const fn (CUInt) bool = undefined,

        getScreenWidth: *const fn () CInt = undefined,
        getScreenHeight: *const fn () CInt = undefined,
        getRenderWidth: *const fn () CInt = undefined,
        getRenderHeight: *const fn () CInt = undefined,
        getWindowPosition: *const fn () Vector2f = undefined,
        getWindowScaleDPI: *const fn () Vector2f = undefined,

        showFPS: *const fn (CInt, CInt) void = undefined,
        getFPS: *const fn () Float = undefined,
        toggleFullscreen: *const fn () void = undefined,
        toggleBorderlessWindowed: *const fn () void = undefined,
        setWindowFlags: *const fn ([]WindowFlag) void = undefined,
        setOpacity: *const fn (o: Float) void = undefined,
        setExitKey: *const fn (KeyboardKey) void = undefined,

        deinit: DeinitFunction = undefined,

        pub fn init(initImpl: *const fn (*IWindowAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}

pub const InputDevice = enum(u8) {
    KEYBOARD,
    GAME_PAD_1,
    GAME_PAD_2,
    MOUSE,
};

pub const InputActionType = enum(u8) {
    ON,
    OFF,
    TYPED,
    RELEASED,
};

pub const InputButtonType = enum(usize) {
    UP,
    RIGHT,
    DOWN,
    LEFT,

    ENTER,
    QUIT,
    FIRE_1,
    FIRE_2,
    PAUSE,

    BUTTON_A,
    BUTTON_B,
    BUTTON_C,
    BUTTON_D,

    BUTTON_W,
    BUTTON_X,
    BUTTON_Y,
    BUTTON_Z,

    BUTTON_0,
    BUTTON_1,
    BUTTON_2,
    BUTTON_3,
    BUTTON_4,
    BUTTON_5,
    BUTTON_6,
    BUTTON_7,
    BUTTON_8,
    BUTTON_9,
};

// Keyboard keys (US keyboard layout)
// NOTE: Use GetKeyPressed() to allow redefining
// required keys for alternative layouts
pub const KeyboardKey = enum(usize) {
    KEY_NULL = 0, // Key: NULL, used for no key pressed
    // Alphanumeric keys
    KEY_APOSTROPHE = 39, // Key: '
    KEY_COMMA = 44, // Key: ,
    KEY_MINUS = 45, // Key: -
    KEY_PERIOD = 46, // Key: .
    KEY_SLASH = 47, // Key: /
    KEY_ZERO = 48, // Key: 0
    KEY_ONE = 49, // Key: 1
    KEY_TWO = 50, // Key: 2
    KEY_THREE = 51, // Key: 3
    KEY_FOUR = 52, // Key: 4
    KEY_FIVE = 53, // Key: 5
    KEY_SIX = 54, // Key: 6
    KEY_SEVEN = 55, // Key: 7
    KEY_EIGHT = 56, // Key: 8
    KEY_NINE = 57, // Key: 9
    KEY_SEMICOLON = 59, // Key: ;
    KEY_EQUAL = 61, // Key: =
    KEY_A = 65, // Key: A | a
    KEY_B = 66, // Key: B | b
    KEY_C = 67, // Key: C | c
    KEY_D = 68, // Key: D | d
    KEY_E = 69, // Key: E | e
    KEY_F = 70, // Key: F | f
    KEY_G = 71, // Key: G | g
    KEY_H = 72, // Key: H | h
    KEY_I = 73, // Key: I | i
    KEY_J = 74, // Key: J | j
    KEY_K = 75, // Key: K | k
    KEY_L = 76, // Key: L | l
    KEY_M = 77, // Key: M | m
    KEY_N = 78, // Key: N | n
    KEY_O = 79, // Key: O | o
    KEY_P = 80, // Key: P | p
    KEY_Q = 81, // Key: Q | q
    KEY_R = 82, // Key: R | r
    KEY_S = 83, // Key: S | s
    KEY_T = 84, // Key: T | t
    KEY_U = 85, // Key: U | u
    KEY_V = 86, // Key: V | v
    KEY_W = 87, // Key: W | w
    KEY_X = 88, // Key: X | x
    KEY_Y = 89, // Key: Y | y
    KEY_Z = 90, // Key: Z | z
    KEY_LEFT_BRACKET = 91, // Key: [
    KEY_BACKSLASH = 92, // Key: '\'
    KEY_RIGHT_BRACKET = 93, // Key: ]
    KEY_GRAVE = 96, // Key: `
    // Function keys
    KEY_SPACE = 32, // Key: Space
    KEY_ESCAPE = 256, // Key: Esc
    KEY_ENTER = 257, // Key: Enter
    KEY_TAB = 258, // Key: Tab
    KEY_BACKSPACE = 259, // Key: Backspace
    KEY_INSERT = 260, // Key: Ins
    KEY_DELETE = 261, // Key: Del
    KEY_RIGHT = 262, // Key: Cursor right
    KEY_LEFT = 263, // Key: Cursor left
    KEY_DOWN = 264, // Key: Cursor down
    KEY_UP = 265, // Key: Cursor up
    KEY_PAGE_UP = 266, // Key: Page up
    KEY_PAGE_DOWN = 267, // Key: Page down
    KEY_HOME = 268, // Key: Home
    KEY_END = 269, // Key: End
    KEY_CAPS_LOCK = 280, // Key: Caps lock
    KEY_SCROLL_LOCK = 281, // Key: Scroll down
    KEY_NUM_LOCK = 282, // Key: Num lock
    KEY_PRINT_SCREEN = 283, // Key: Print screen
    KEY_PAUSE = 284, // Key: Pause
    KEY_F1 = 290, // Key: F1
    KEY_F2 = 291, // Key: F2
    KEY_F3 = 292, // Key: F3
    KEY_F4 = 293, // Key: F4
    KEY_F5 = 294, // Key: F5
    KEY_F6 = 295, // Key: F6
    KEY_F7 = 296, // Key: F7
    KEY_F8 = 297, // Key: F8
    KEY_F9 = 298, // Key: F9
    KEY_F10 = 299, // Key: F10
    KEY_F11 = 300, // Key: F11
    KEY_F12 = 301, // Key: F12
    KEY_LEFT_SHIFT = 340, // Key: Shift left
    KEY_LEFT_CONTROL = 341, // Key: Control left
    KEY_LEFT_ALT = 342, // Key: Alt left
    KEY_LEFT_SUPER = 343, // Key: Super left
    KEY_RIGHT_SHIFT = 344, // Key: Shift right
    KEY_RIGHT_CONTROL = 345, // Key: Control right
    KEY_RIGHT_ALT = 346, // Key: Alt right
    KEY_RIGHT_SUPER = 347, // Key: Super right
    KEY_KB_MENU = 348, // Key: KB menu
    // Keypad keys
    KEY_KP_0 = 320, // Key: Keypad 0
    KEY_KP_1 = 321, // Key: Keypad 1
    KEY_KP_2 = 322, // Key: Keypad 2
    KEY_KP_3 = 323, // Key: Keypad 3
    KEY_KP_4 = 324, // Key: Keypad 4
    KEY_KP_5 = 325, // Key: Keypad 5
    KEY_KP_6 = 326, // Key: Keypad 6
    KEY_KP_7 = 327, // Key: Keypad 7
    KEY_KP_8 = 328, // Key: Keypad 8
    KEY_KP_9 = 329, // Key: Keypad 9
    KEY_KP_DECIMAL = 330, // Key: Keypad .
    KEY_KP_DIVIDE = 331, // Key: Keypad /
    KEY_KP_MULTIPLY = 332, // Key: Keypad *
    KEY_KP_SUBTRACT = 333, // Key: Keypad -
    KEY_KP_ADD = 334, // Key: Keypad +
    KEY_KP_ENTER = 335, // Key: Keypad Enter
    KEY_KP_EQUAL = 336, // Key: Keypad =
    // Android key buttons
    KEY_BACK = 4, // Key: Android back button
    KEY_MENU = 5, // Key: Android menu button
    KEY_VOLUME_UP = 24, // Key: Android volume up button
    KEY_VOLUME_DOWN = 25, // Key: Android volume down button
};

// Mouse buttons
pub const MouseAction = enum(usize) {
    MOUSE_BUTTON_LEFT = 0, // Mouse button left
    MOUSE_BUTTON_RIGHT = 1, // Mouse button right
    MOUSE_BUTTON_MIDDLE = 2, // Mouse button middle (pressed wheel)
    MOUSE_BUTTON_SIDE = 3, // Mouse button side (advanced mouse device)
    MOUSE_BUTTON_EXTRA = 4, // Mouse button extra (advanced mouse device)
    MOUSE_BUTTON_FORWARD = 5, // Mouse button forward (advanced mouse device)
    MOUSE_BUTTON_BACK = 6, // Mouse button back (advanced mouse device)
};

pub const GamepadAction = enum(usize) {
    GAMEPAD_BUTTON_UNKNOWN = 0, // Unknown button, just for error checking
    GAMEPAD_BUTTON_LEFT_FACE_UP = 1, // Gamepad left DPAD up button
    GAMEPAD_BUTTON_LEFT_FACE_RIGHT = 2, // Gamepad left DPAD right button
    GAMEPAD_BUTTON_LEFT_FACE_DOWN = 3, // Gamepad left DPAD down button
    GAMEPAD_BUTTON_LEFT_FACE_LEFT = 4, // Gamepad left DPAD left button
    GAMEPAD_BUTTON_RIGHT_FACE_UP = 5, // Gamepad right button up (i.e. PS3: Triangle, Xbox: Y)
    GAMEPAD_BUTTON_RIGHT_FACE_RIGHT = 6, // Gamepad right button right (i.e. PS3: Circle, Xbox: B)
    GAMEPAD_BUTTON_RIGHT_FACE_DOWN = 7, // Gamepad right button down (i.e. PS3: Cross, Xbox: A)
    GAMEPAD_BUTTON_RIGHT_FACE_LEFT = 8, // Gamepad right button left (i.e. PS3: Square, Xbox: X)
    GAMEPAD_BUTTON_LEFT_TRIGGER_1 = 9, // Gamepad top/back trigger left (first), it could be a trailing button
    GAMEPAD_BUTTON_LEFT_TRIGGER_2 = 10, // Gamepad top/back trigger left (second), it could be a trailing button
    GAMEPAD_BUTTON_RIGHT_TRIGGER_1 = 11, // Gamepad top/back trigger right (one), it could be a trailing button
    GAMEPAD_BUTTON_RIGHT_TRIGGER_2 = 12, // Gamepad top/back trigger right (second), it could be a trailing button
    GAMEPAD_BUTTON_MIDDLE_LEFT = 13, // Gamepad center buttons, left one (i.e. PS3: Select)
    GAMEPAD_BUTTON_MIDDLE = 14, // Gamepad center buttons, middle one (i.e. PS3: PS, Xbox: XBOX)
    GAMEPAD_BUTTON_MIDDLE_RIGHT = 15, // Gamepad center buttons, right one (i.e. PS3: Start)
    GAMEPAD_BUTTON_LEFT_THUMB = 16, // Gamepad joystick pressed button left
    GAMEPAD_BUTTON_RIGHT_THUMB = 17, // Gamepad joystick pressed button right
};

pub const GamepadAxis = enum(usize) {
    GAMEPAD_AXIS_LEFT_X = 0, // Gamepad left stick X axis
    GAMEPAD_AXIS_LEFT_Y = 1, // Gamepad left stick Y axis
    GAMEPAD_AXIS_RIGHT_X = 2, // Gamepad right stick X axis
    GAMEPAD_AXIS_RIGHT_Y = 3, // Gamepad right stick Y axis
    GAMEPAD_AXIS_LEFT_TRIGGER = 4, // Gamepad back trigger left, pressure level: [1..-1]
    GAMEPAD_AXIS_RIGHT_TRIGGER = 5, // Gamepad back trigger right, pressure level: [1..-1]
};

pub fn IInputAPI() type {
    return struct {
        const Self = @This();

        pub fn checkButtonPressed(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.ON, null);
        }

        pub fn checkButtonOff(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.OFF, null);
        }

        pub fn checkButtonReleased(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.RELEASED, null);
        }

        pub fn checkButtonTyped(self: Self, button: InputButtonType) bool {
            return self.checkButton(button, InputActionType.TYPED, null);
        }

        pub fn setKeyMapping(self: Self, key: KeyboardKey, button: InputButtonType) void {
            self.setKeyButtonMapping(@intFromEnum(key), button);
        }

        // check the button type for specified action. Button type must have been mapped on one or many devices
        checkButton: *const fn (InputButtonType, InputActionType, ?InputDevice) bool = undefined,
        // get the current normalized action value between -1 and 1
        // if the action is digital on/off --> 0 <= off, > 0 = on
        getButtonValue: *const fn (InputButtonType, ?InputDevice) Float = undefined,
        // clears all mappings
        clear_mappings: *const fn () void = undefined,

        // KEYBOARD
        // Get key pressed (keycode), call it multiple times for keys queued, returns 0 when the queue is empty
        getKeyPressed: *const fn () usize = undefined,
        // Get char pressed (unicode), call it multiple times for chars queued, returns 0 when the queue is empty
        getCharPressed: *const fn () usize = undefined,
        // key mappings
        setKeyButtonMapping: *const fn (keycode: usize, InputButtonType) void = undefined,

        // GAMEPAD
        // Check if a gamepad is available
        isGamepadAvailable: *const fn (InputDevice) bool = undefined,
        // Get gamepad internal name id
        getGamepadName: *const fn (InputDevice) String = undefined,

        getGamepadAxisMovement: *const fn (InputDevice, GamepadAxis) Float = undefined,
        // gamepad mappings
        setGamepad1Mapping: *const fn (InputDevice) void = undefined,
        setGamepad2Mapping: *const fn (InputDevice) void = undefined,
        setGamepadButtonMapping: *const fn (InputDevice, GamepadAction, InputButtonType) void = undefined,

        // MOUSE
        getMousePosition: *const fn () PosF = undefined,
        getMouseDelta: *const fn () Vector2f = undefined,
        setMouseButtonMapping: *const fn (MouseAction, InputButtonType) void = undefined,

        deinit: DeinitFunction = undefined,

        pub fn init(initImpl: *const fn (*IInputAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}

pub const SoundBinding = struct {
    id: BindingId,
    channel_1: ?BindingId = null,
    channel_2: ?BindingId = null,
    channel_3: ?BindingId = null,
    channel_4: ?BindingId = null,
    channel_5: ?BindingId = null,
    channel_6: ?BindingId = null,

    pub fn getBindingId(self: SoundBinding, channel: ?usize) BindingId {
        if (channel == null)
            return self.id;

        return switch (channel.?) {
            1 => if (self.channel_1) |b| b else self.id,
            2 => if (self.channel_2) |b| b else self.id,
            3 => if (self.channel_3) |b| b else self.id,
            4 => if (self.channel_4) |b| b else self.id,
            5 => if (self.channel_5) |b| b else self.id,
            6 => if (self.channel_6) |b| b else self.id,
            else => self.id,
        };
    }
};

pub fn IAudioAPI() type {
    return struct {
        const Self = @This();

        initAudioDevice: *const fn () void = undefined,
        closeAudioDevice: *const fn () void = undefined,
        setMasterVolume: *const fn (volume: Float) void = undefined,
        getMasterVolume: *const fn () Float = undefined,

        loadSound: *const fn (file: String, channels: utils.IntBitMask) IOErrors!SoundBinding = undefined,
        disposeSound: *const fn (SoundBinding) void = undefined,
        playSound: *const fn (BindingId, volume: ?Float, pitch: ?Float, pan: ?Float, looping: bool) void = undefined,
        stopSound: *const fn (BindingId) void = undefined,
        pauseSound: *const fn (BindingId) void = undefined,
        resumeSound: *const fn (BindingId) void = undefined,
        isSoundPlaying: *const fn (BindingId) bool = undefined,
        setSoundVolume: *const fn (BindingId, volume: Float) void = undefined,
        setSoundPitch: *const fn (BindingId, pitch: Float) void = undefined,
        setSoundPan: *const fn (BindingId, pan: Float) void = undefined,

        loadMusic: *const fn (file: String) IOErrors!BindingId = undefined,
        disposeMusic: *const fn (BindingId) void = undefined,
        playMusic: *const fn (BindingId) void = undefined,
        stopMusic: *const fn (BindingId) void = undefined,
        pauseMusic: *const fn (BindingId) void = undefined,
        resumeMusic: *const fn (BindingId) void = undefined,
        isMusicPlaying: *const fn (BindingId) bool = undefined,
        setMusicVolume: *const fn (BindingId, volume: Float) void = undefined,
        setMusicPitch: *const fn (BindingId, pitch: Float) void = undefined,
        setMusicPan: *const fn (BindingId, pan: Float) void = undefined,
        getMusicTimeLength: *const fn (BindingId) Float = undefined,
        getMusicTimePlayed: *const fn (BindingId) Float = undefined,

        deinit: DeinitFunction = undefined,

        pub fn init(initImpl: *const fn (*IAudioAPI()) void) Self {
            var self = Self{};
            _ = initImpl(&self);
            return self;
        }

        pub fn initDummy() Self {
            var self = Self{};
            self.deinit = dummyDeinit;
            return self;
        }
    };
}
