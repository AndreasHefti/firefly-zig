const std = @import("std");
const inari = @import("../../inari.zig");
const utils = inari.utils;
const api = inari.firefly.api;
const trait = std.meta.trait;

const Allocator = std.mem.Allocator;
const EventDispatch = utils.EventDispatch;
const Component = api.Component;
const ComponentEvent = Component.ComponentEvent;
const ComponentListener = Component.ComponentListener;
const EntityKindPredicate = api.EntityKindPredicate;
const UpdateEvent = api.UpdateEvent;
const UpdateListener = api.UpdateListener;
const RenderEvent = api.RenderEvent;
const RenderListener = api.RenderListener;
const UpdateScheduler = api.Timer.UpdateScheduler;
const Engine = api.Engine;
const Entity = api.Entity;
const Kind = utils.Kind;
const Aspect = utils.Aspect;
const AspectGroup = utils.AspectGroup;
const String = utils.String;
const Index = utils.Index;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const NO_NAME = utils.NO_NAME;
const System = @This();

pub usingnamespace Component.API.ComponentTrait(System, .{ .name = "System", .subscription = false });

// struct fields of a System
id: Index = UNDEF_INDEX,
name: String = NO_NAME,
info: String = NO_NAME,
// struct function references of a System
onConstruct: ?*const fn () void = null,
onActivation: ?*const fn (bool) void = null,
onDestruct: ?*const fn () void = null,

pub fn construct(self: *System) void {
    if (self.onConstruct) |onConstruct| {
        onConstruct();
    }
}

pub fn activation(self: *System, active: bool) void {
    if (self.onActivation) |onActivation| {
        onActivation(active);
    }
}

pub fn destruct(self: *System) void {
    if (self.onDestruct) |onDestruct| {
        onDestruct();
    }
}

pub fn format(
    self: System,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    try writer.print(
        "{s}[ id:{d}, info:{s} ]",
        .{ self.name, self.id, self.info },
    );
}
