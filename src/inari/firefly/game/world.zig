const std = @import("std");
const firefly = @import("../firefly.zig");

const Component = firefly.api.Component;

const PosF = firefly.utils.PosF;
const Index = firefly.utils.Index;
const String = firefly.utils.String;
const Float = firefly.utils.Float;
const Color = firefly.utils.Color;
const BlendMode = firefly.api.BlendMode;
const RectF = firefly.utils.RectF;
const CInt = firefly.utils.CInt;
const BindingId = firefly.api.BindingId;
const NO_BINDING = firefly.api.NO_BINDING;
const UNDEF_INDEX = firefly.utils.UNDEF_INDEX;

//////////////////////////////////////////////////////////////
//// game world init
//////////////////////////////////////////////////////////////

var initialized = false;
pub fn init() void {
    defer initialized = true;
    if (initialized)
        return;

    Component.registerComponent(Room);
    Component.registerComponent(Area);
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Area
//////////////////////////////////////////////////////////////

pub const Area = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "Area",
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    _composite_id: ?Index = null,
};

//////////////////////////////////////////////////////////////
//// Room
//////////////////////////////////////////////////////////////

pub const RoomLayer = struct {
    name: String,

    _layer_id: ?Index = null,
};

pub const Room = struct {
    pub usingnamespace Component.Trait(
        @This(),
        .{
            .name = "Room",
            .subscription = false,
        },
    );

    id: Index = UNDEF_INDEX,
    name: ?String = null,

    view_id: Index,

    _composite_id: ?Index = null,
};