const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const graphics = firefly.graphics;
const Entity = firefly.api.Entity;
const ETransform = graphics.ETransform;
const EView = graphics.EView;
const EText = graphics.EText;
const Font = graphics.Font;
const Allocator = std.mem.Allocator;
const View = graphics.View;
const Index = utils.Index;
const String = utils.String;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 400, 60, "Mouse Pointer on multiple Viewport", loadWithView);
}

var buffers: [3][2][11:0]u8 = .{
    .{
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
    },
    .{
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
    },
    .{
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
        .{ ' ', '0', '0', '0', '0', ':', ' ', '0', '0', '0', '0' },
    },
};

fn loadWithView() void {
    const viewId1 = View.Component.newActive(.{
        .name = "View1",
        .position = .{ 0, 0 },
        .projection = .{
            .position = .{ 0, 0 },
            .width = 600,
            .height = 400,
            .zoom = 3,
        },
    });
    View.Control.addActive(viewId1, update, null);

    const viewId2 = View.Component.newActive(.{
        .name = "View2",
        .position = .{ 0, 200 },
        .projection = .{
            .clear_color = .{ 30, 30, 30, 255 },
            .position = .{ 0, 0 },
            .width = 350,
            .height = 200,
            .zoom = 2,
        },
    });
    View.Control.addActive(viewId2, update, null);

    const viewId3 = View.Component.newActive(.{
        .name = "View3",
        .position = .{ 350, 200 },
        .projection = .{
            .clear_color = .{ 20, 20, 20, 255 },
            .position = .{ 0, 0 },
            .width = 250,
            .height = 200,
            .zoom = 1,
        },
    });
    View.Control.addActive(viewId3, update, null);

    const font_id = Font.Component.newActive(.{
        .resource = "resources/mini_font.png",
    });

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 5, 20 } })
        .withComponent(EView{ .view_id = viewId1 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[0][0],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 5, 35 } })
        .withComponent(EView{ .view_id = viewId1 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[0][1],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 10, 10 } })
        .withComponent(EView{ .view_id = viewId2 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[1][0],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 10, 25 } })
        .withComponent(EView{ .view_id = viewId2 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[1][1],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 10, 10 } })
        .withComponent(EView{ .view_id = viewId3 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[2][0],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();

    Entity.build(.{})
        .withComponent(ETransform{ .position = .{ 10, 30 } })
        .withComponent(EView{ .view_id = viewId3 })
        .withComponent(EText{
        .font_id = font_id,
        .text = &buffers[2][1],
        .size = 10,
        .char_spacing = 0,
    })
        .activate();
}

fn update(ctx: *firefly.api.CallContext) void {
    const pos = firefly.api.input.getMousePosition();
    var view = View.Component.byId(ctx.caller_id);

    apply_buff(
        view.transform_world_position(pos, false),
        &buffers[ctx.caller_id][0],
    );
    apply_buff(
        view.transform_world_position(pos, true),
        &buffers[ctx.caller_id][1],
    );
}

fn apply_buff(pos: utils.Vector2f, buff: *[11]u8) void {
    const pos_x = firefly.utils.f32_usize(@abs(pos[0]));
    const pos_y = firefly.utils.f32_usize(@abs(pos[1]));

    buff[4] = utils.digit(pos_x, 0);
    buff[3] = utils.digit(pos_x, 1);
    buff[2] = utils.digit(pos_x, 2);
    buff[1] = utils.digit(pos_x, 3);
    buff[0] = if (pos[0] > 0) ' ' else '-';
    buff[10] = utils.digit(pos_y, 0);
    buff[9] = utils.digit(pos_y, 1);
    buff[8] = utils.digit(pos_y, 2);
    buff[7] = utils.digit(pos_y, 3);
    buff[6] = if (pos[1] > 0) ' ' else '-';
}
