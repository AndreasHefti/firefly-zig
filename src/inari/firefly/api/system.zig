const std = @import("std");
const utils = @import("../../utils/utils.zig");
const api = @import("api.zig");

const trait = std.meta.trait;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const String = utils.String;

var SYSTEMS: StringHashMap(System) = undefined;
var initialized = false;

pub fn init() void {
    defer initialized = true;
    if (!initialized) {
        SYSTEMS = StringHashMap(System).init(api.ALLOC);
    }
}

pub fn deinit() void {
    if (initialized) {
        var it = SYSTEMS.valueIterator();
        while (it.next()) |system| {
            system.deinit();
        }
        SYSTEMS.deinit();
        initialized = false;
    }
}

const SystemInfo = struct {
    name: String = undefined,
};

pub const System = struct {
    activate: *const fn (bool) void = undefined,
    getInfo: *const fn () SystemInfo = undefined,
    deinit: *const fn () void = undefined,

    pub fn initSystem(comptime systemType: type) !*System {
        // check init
        if (!initialized) {
            @panic("System not initialized.");
        }
        comptime {
            if (!trait.is(.Struct)(systemType)) @compileError("Expects System is a struct.");
            if (!trait.hasFn("init")(systemType)) @compileError("Expects System to have fn 'init'.");
            if (!trait.hasFn("getInfo")(systemType)) @compileError("Expects System to have fn 'getInfo'.");
            if (!trait.hasFn("activate")(systemType)) @compileError("Expects System to have fn 'activate'.");
            if (!trait.hasFn("deinit")(systemType)) @compileError("Expects System to have fn 'deinit'.");
        }
        systemType.init();
        var system = System{
            .activate = systemType.activate,
            .getInfo = systemType.getInfo,
            .deinit = systemType.deinit,
        };
        var name: String = systemType.getInfo().name;
        try SYSTEMS.put(name, system);
        return SYSTEMS.getPtr(name).?;
    }

    pub fn activate(name: String, active: bool) void {
        const sys = getSystem(name) orelse unreachable;
        sys.activate(active);
    }

    pub fn getSystem(name: String) ?*System {
        var it = SYSTEMS.valueIterator();
        while (it.next()) |system| {
            if (std.mem.eql(u8, system.getInfo().name, name)) {
                return system;
            }
        }
        return null;
    }
};

const ExampleSystem = struct {
    const info = SystemInfo{ .name = "ExampleSystem" };

    pub fn getInfo() SystemInfo {
        return info;
    }

    pub fn init() void {
        std.debug.print("ExampleSystem init called\n", .{});
    }

    pub fn deinit() void {
        std.debug.print("ExampleSystem deinit called\n", .{});
    }

    pub fn activate(active: bool) void {
        std.debug.print("ExampleSystem activate {any} called\n", .{active});
    }
};

// test "initialization" {
//
//     try firefly.moduleInitDebug(std.testing.allocator);
//     defer firefly.moduleDeinit();

//     var exampleSystem = try System.initSystem(ExampleSystem);
//     try std.testing.expectEqualStrings("ExampleSystem", exampleSystem.getInfo().name);
//     var systemPtr = System.getSystem("ExampleSystem").?;
//     try std.testing.expectEqualStrings("ExampleSystem", systemPtr.getInfo().name);
//     System.activate(ExampleSystem.info.name, false);
// }
