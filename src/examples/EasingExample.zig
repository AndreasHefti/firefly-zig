const std = @import("std");
const firefly = @import("../inari/firefly/firefly.zig");
const utils = firefly.utils;
const Texture = firefly.graphics.Texture;
const SpriteTemplate = firefly.graphics.SpriteTemplate;
const Entity = firefly.api.Entity;
const ETransform = firefly.graphics.ETransform;
const ESprite = firefly.graphics.ESprite;
const EasedValueIntegrator = firefly.physics.EasedValueIntegrator;
const Allocator = std.mem.Allocator;
const Easing = utils.Easing;
const String = utils.String;
const Float = utils.Float;
const EText = firefly.graphics.EText;

pub fn run(init_c: firefly.api.InitContext) !void {
    try firefly.init(init_c);
    defer firefly.deinit();

    firefly.Engine.start(600, 1000, 60, "Easing", init);
}

var ypos: Float = 30;

fn init() void {
    _ = Texture.Component.newActive(.{
        .name = "TestTexture",
        .resource = "resources/logo.png",
        .is_mipmap = false,
    });

    _ = SpriteTemplate.Component.new(.{
        .name = "Sprite",
        .texture_name = "TestTexture",
        .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
    });

    create("Linear:", Easing.Linear);
    create("Quad In:", Easing.Quad_In);
    create("Quad Out:", Easing.Quad_Out);
    create("Quad In Out:", Easing.Quad_In_Out);
    create("Cubic In:", Easing.Cubic_In);
    create("Cubic Out:", Easing.Cubic_Out);
    create("Cubic In Out:", Easing.Cubic_In_Out);
    create("Quart In:", Easing.Quart_In);
    create("Quart Out:", Easing.Quart_Out);
    create("Quart In Out:", Easing.Quart_In_Out);
    create("Exp In:", Easing.Exponential_In);
    create("Exp Out:", Easing.Exponential_Out);
    create("Exp In Out:", Easing.Exponential_In_Out);
    create("Sin In:", Easing.Sin_In);
    create("Sin Out:", Easing.Sin_Out);
    create("Sin In Out:", Easing.Sin_In_Out);
    create("Circ In:", Easing.Circ_In);
    create("Circ Out:", Easing.Circ_Out);
    create("Circ In Out:", Easing.Circ_In_Out);
    create("Elastic In:", Easing.Elastic_In);
    create("Elastic Out:", Easing.Elastic_Out);
    create("Back In:", Easing.Back_In);
    create("Back Out:", Easing.Back_Out);
    create("Bounce In:", Easing.Bounce_In);
    create("Bounce Out:", Easing.Bounce_Out);
    create("BackIn(5):", utils.createEasing(utils.BackInEasing{ .back_factor = 5 }, firefly.api.POOL_ALLOC));
    create("BackIn(10):", utils.createEasing(utils.BackInEasing{ .back_factor = 10 }, firefly.api.POOL_ALLOC));
}

fn create(name: String, easing: Easing) void {
    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ 10, ypos } },
        EText{ .text = name, .size = 20, .char_spacing = 2 },
    });

    _ = Entity.newActive(.{}, .{
        ETransform{ .position = .{ 200, ypos } },
        ESprite{ .template_id = SpriteTemplate.Naming.byName("Sprite").?.id },
        firefly.physics.EEasingAnimation{
            .duration = 5000,
            .looping = true,
            .inverse_on_loop = true,
            .active_on_init = true,
            .start_value = 200,
            .end_value = 500,
            .easing = easing,
            .property_ref = ETransform.Property.XPos,
        },
    });

    ypos += 35;
}
