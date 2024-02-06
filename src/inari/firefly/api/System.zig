const std = @import("std");

const Allocator = std.mem.Allocator;
const trait = std.meta.trait;

const api = @import("api.zig");
const DynArray = api.utils.dynarray.DynArray;
const ArrayList = std.ArrayList;
const Component = api.Component;
const Kind = api.utils.aspect.Kind;
const aspect = api.utils.aspect;
const Aspect = aspect.Aspect;
const AspectGroup = aspect.AspectGroup;
const String = api.utils.String;
const Index = api.Index;
const UNDEF_INDEX = api.UNDEF_INDEX;
const NO_NAME = api.utils.NO_NAME;
const System = @This();

// component type fields
pub const NULL_VALUE = System{};
pub const COMPONENT_NAME = "System";
pub const pool = Component.ComponentPool(System);
// component type pool references
pub var type_aspect: *Aspect = undefined;
pub var new: *const fn (System) *System = undefined;
pub var exists: *const fn (Index) bool = undefined;
pub var existsName: *const fn (String) bool = undefined;
pub var get: *const fn (Index) *System = undefined;
pub var byId: *const fn (Index) *const System = undefined;
pub var byName: *const fn (String) *const System = undefined;
pub var activateById: *const fn (Index, bool) void = undefined;
pub var activateByName: *const fn (String, bool) void = undefined;
pub var disposeById: *const fn (Index) void = undefined;
pub var disposeByName: *const fn (String) void = undefined;
pub var subscribe: *const fn (Component.EventListener) void = undefined;
pub var unsubscribe: *const fn (Component.EventListener) void = undefined;

// struct fields of a System
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
info: String = NO_NAME,
// struct function references of a System
onInit: ?*const fn () void = null,
onActivation: ?*const fn (bool) void = null,
onDispose: ?*const fn () void = null,

pub fn onNew(id: Index) void {
    if (System.get(id).onInit) |onInit| {
        onInit();
    }
}

pub fn onActivation(id: Index, active: bool) void {
    if (System.get(id).onActivation) |onAct| {
        onAct(active);
    }
}

pub fn onDispose(id: Index) void {
    if (System.get(id).onDispose) |onDisp| {
        onDisp();
    }
}

// const api = @import("api.zig");
// const utils = api.utils;
// const trait = std.meta.trait;
// const Allocator = std.mem.Allocator;
// const ArrayList = std.ArrayList;
// const StringHashMap = std.StringHashMap;
// const String = utils.String;

// var SYSTEMS: StringHashMap(System) = undefined;
// var initialized = false;

// pub fn init() void {
//     defer initialized = true;
//     if (!initialized) {
//         SYSTEMS = StringHashMap(System).init(api.ALLOC);
//     }
// }

// pub fn deinit() void {
//     if (initialized) {
//         var it = SYSTEMS.valueIterator();
//         while (it.next()) |system| {
//             system.deinit();
//         }
//         SYSTEMS.deinit();
//         initialized = false;
//     }
// }

// const SystemInfo = struct {
//     name: String = undefined,
// };

// pub const System = struct {
//     activate: *const fn (bool) void = undefined,
//     getInfo: *const fn () SystemInfo = undefined,
//     deinit: *const fn () void = undefined,

//     pub fn initSystem(comptime systemType: type) !*System {
//         // check init
//         if (!initialized) {
//             @panic("System not initialized.");
//         }
//         comptime {
//             if (!trait.is(.Struct)(systemType)) @compileError("Expects System is a struct.");
//             if (!trait.hasFn("init")(systemType)) @compileError("Expects System to have fn 'init'.");
//             if (!trait.hasFn("getInfo")(systemType)) @compileError("Expects System to have fn 'getInfo'.");
//             if (!trait.hasFn("activate")(systemType)) @compileError("Expects System to have fn 'activate'.");
//             if (!trait.hasFn("deinit")(systemType)) @compileError("Expects System to have fn 'deinit'.");
//         }
//         systemType.init();
//         var system = System{
//             .activate = systemType.activate,
//             .getInfo = systemType.getInfo,
//             .deinit = systemType.deinit,
//         };
//         var name: String = systemType.getInfo().name;
//         try SYSTEMS.put(name, system);
//         return SYSTEMS.getPtr(name).?;
//     }

//     pub fn activate(name: String, active: bool) void {
//         const sys = getSystem(name) orelse unreachable;
//         sys.activate(active);
//     }

//     pub fn getSystem(name: String) ?*System {
//         var it = SYSTEMS.valueIterator();
//         while (it.next()) |system| {
//             if (std.mem.eql(u8, system.getInfo().name, name)) {
//                 return system;
//             }
//         }
//         return null;
//     }
// };

// const ExampleSystem = struct {
//     const info = SystemInfo{ .name = "ExampleSystem" };

//     pub fn getInfo() SystemInfo {
//         return info;
//     }

//     pub fn init() void {
//         std.debug.print("ExampleSystem init called\n", .{});
//     }

//     pub fn deinit() void {
//         std.debug.print("ExampleSystem deinit called\n", .{});
//     }

//     pub fn activate(active: bool) void {
//         std.debug.print("ExampleSystem activate {any} called\n", .{active});
//     }
// };

// //////////////////////////////////////////////////////////////
// //// TESTING
// //////////////////////////////////////////////////////////////

// // test "initialization" {
// //
// //     try firefly.moduleInitDebug(std.testing.allocator);
// //     defer firefly.moduleDeinit();

// //     var exampleSystem = try System.initSystem(ExampleSystem);
// //     try std.testing.expectEqualStrings("ExampleSystem", exampleSystem.getInfo().name);
// //     var systemPtr = System.getSystem("ExampleSystem").?;
// //     try std.testing.expectEqualStrings("ExampleSystem", systemPtr.getInfo().name);
// //     System.activate(ExampleSystem.info.name, false);
// // }
