const std = @import("std");
const firefly = @import("../firefly.zig");

const utils = firefly.utils;
const api = firefly.api;

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
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;
}

//////////////////////////////////////////////////////////////
//// Area
//////////////////////////////////////////////////////////////

pub const Area = struct {};

//////////////////////////////////////////////////////////////
//// Room
//////////////////////////////////////////////////////////////

// pub const Room = struct {
//     pub fn createRoom(name: String) Index {
//         if (api.Composite.existsName(name))
//             @panic("Composite with name exists: " ++ name);

//         return api.Composite.new(.{ .name = name }).id;
//     }

//     pub fn withLoadTask(room_name: String, task: api.Task) void {

//     }

//     pub fn withTileSetTask(room_name: String, attributes: api.CallAttributes) void {}

//     pub fn withTileMappingTask(room_name: String, attributes: api.CallAttributes) void {}

//     pub fn withTileGridTask(room_name: String, attributes: api.CallAttributes) void {}

//     pub fn withObjectTask(room_name: String, object: api.CompositeObject) void {
//         if (api.Composite.byName(name)) |c| {
//             _ = c.withObject(object);
//         } else {
//             @panic("Composite with name exists: " ++ name);
//         }
//     }
// };
