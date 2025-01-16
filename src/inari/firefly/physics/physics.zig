const std = @import("std");
const firefly = @import("../firefly.zig");
const animation = @import("animation.zig");
const movement = @import("movement.zig");
const audio = @import("audio.zig");
const contact = @import("contact.zig");
const Float = firefly.utils.Float;
const Index = firefly.utils.Index;
const String = firefly.utils.String;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const EARTH_GRAVITY: Float = 9.8;

pub const Animation = animation.Animation;
pub const AnimationSystem = animation.AnimationSystem;
pub const IndexFrame = animation.IndexFrame;
pub const IndexFrameList = animation.IndexFrameList;
pub const EasedValueIntegrator = animation.EasedValueIntegrator;
pub const EasedColorIntegrator = animation.EasedColorIntegrator;
pub const IndexFrameIntegrator = animation.IndexFrameIntegrator;
pub const BezierSplineIntegrator = animation.BezierSplineIntegrator;
pub const EAnimations = animation.EAnimations;
pub const EAnimationReference = animation.EAnimationReference;
pub const EEasingAnimation = animation.EEasingAnimation;
pub const EEasedColorAnimation = animation.EEasedColorAnimation;
pub const EIndexFrameAnimation = animation.EIndexFrameAnimation;

pub const MovFlags = movement.MovFlags;
pub const EMovement = movement.EMovement;
pub const MovementAspectGroup = firefly.utils.AspectGroup("Movement");
pub const MovementAspect = MovementAspectGroup.Aspect;
pub const MovementKind = MovementAspectGroup.Kind;
pub const MovementEvent = movement.MovementEvent;
pub const MovementListener = movement.MovementListener;
pub const subscribeMovement = movement.subscribe;
pub const unsubscribeMovement = movement.unsubscribe;
pub const MoveIntegrator = *const fn (movement: *EMovement, delta_time_seconds: Float) bool;
pub const MovementSystem = movement.MovementSystem;

pub const EMovementConstraint = movement.EMovementConstraint;
pub const SimpleStepIntegrator = movement.SimpleStepIntegrator;
pub const FPSStepIntegrator = movement.FPSStepIntegrator;
pub const VerletIntegrator = movement.VerletIntegrator;
pub const EulerIntegrator = movement.EulerIntegrator;
pub const DefaultVelocityConstraint: EMovementConstraint = movement.DefaultVelocityConstraint;

pub const AudioPlayer = audio.AudioPlayer;
pub const Sound = audio.Sound;
pub const Music = audio.Music;

pub const ContactBounds = contact.ContactBounds;
pub const Contact = contact.Contact;
pub const ContactScan = contact.ContactScan;
pub const EContact = contact.EContact;
pub const EContactScan = contact.EContactScan;
pub const ContactSystem = contact.ContactSystem;
pub const ContactGizmosRenderer = contact.ContactGizmosRenderer;
pub const ContactScanGizmosRenderer = contact.ContactScanGizmosRenderer;
pub const CollisionResolverFunction = contact.CollisionResolverFunction;
pub const CollisionResolver = contact.CollisionResolver;
pub const VoidCollisionResolver = contact.VoidCollisionResolver;
pub const ContactConstraint = contact.ContactConstraint;
pub const ContactCallbackFunction = contact.ContactCallbackFunction;
pub const IContactMap = contact.IContactMap;
// Contact Type Aspects
pub const ContactTypeAspectGroup = firefly.utils.AspectGroup("ContactType");
pub const ContactTypeAspect = ContactTypeAspectGroup.Aspect;
pub const ContactTypeKind = ContactTypeAspectGroup.Kind;
// Contact Material Aspects
pub const ContactMaterialAspectGroup = firefly.utils.AspectGroup("ContactMaterial");
pub const ContactMaterialAspect = ContactMaterialAspectGroup.Aspect;
pub const ContactMaterialKind = ContactMaterialAspectGroup.Kind;

//////////////////////////////////////////////////////////////
//// module init
//////////////////////////////////////////////////////////////

var initialized = false;

pub fn init(_: firefly.api.InitContext) !void {
    defer initialized = true;
    if (initialized)
        return;

    animation.init();
    movement.init();
    audio.init();
    contact.init();
}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    animation.deinit();
    movement.deinit();
    audio.deinit();
    contact.deinit();
}

pub fn getDebugCollisionResolver() *CollisionResolver {
    if (!VoidCollisionResolver.Component.existsByName("DEBUG_RESOLVER")) {
        _ = VoidCollisionResolver.Component.new(.{
            .name = "DEBUG_RESOLVER",
            .resolve = debugCollisionResolver,
        });
    }

    return CollisionResolver.Naming.byName("DEBUG_RESOLVER").?;
}

fn debugCollisionResolver(entity_id: Index, _: Index) void {
    const entity = firefly.api.Entity.Component.byId(entity_id);
    const transform = firefly.graphics.ETransform.Component.byId(entity_id);
    const scans = EContactScan.Component.byId(entity_id);

    std.debug.print("******************************************\n", .{});
    std.debug.print("Resolve collision on entity: {any}\n\n", .{entity});
    std.debug.print("Transform: {any}\n\n", .{transform});
    var next = scans.constraints.nextSetBit(0);
    while (next) |i| {
        const constraint = ContactConstraint.Component.byId(i);
        std.debug.print("Contact Constraint: \n{any}\n\n", .{constraint});
        next = scans.constraints.nextSetBit(i + 1);
    }
    std.debug.print("******************************************\n", .{});
}
