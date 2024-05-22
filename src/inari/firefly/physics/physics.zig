const std = @import("std");
const firefly = @import("../firefly.zig");
const animation = @import("animation.zig");
const movement = @import("movement.zig");
const audio = @import("audio.zig");
const contact = @import("contact.zig");
const Float = firefly.utils.Float;

//////////////////////////////////////////////////////////////
//// Public API declarations
//////////////////////////////////////////////////////////////

pub const Gravity: Float = 9.8;

pub const EasedValueIntegration = animation.EasedValueIntegration;
pub const IAnimation = animation.IAnimation;
pub const Animation = animation.Animation;
pub const EAnimation = animation.EAnimation;
pub const AnimationSystem = animation.AnimationSystem;
pub const IndexFrame = animation.IndexFrame;
pub const IndexFrameList = animation.IndexFrameList;
pub const IndexFrameIntegration = animation.IndexFrameIntegration;
pub const BezierCurveIntegration = animation.BezierCurveIntegration;

pub const EMovement = movement.EMovement;
pub const MovementEvent = movement.MovementEvent;
pub const MovementListener = movement.MovementListener;
pub const subscribe = movement.subscribe;
pub const unsubscribe = movement.unsubscribe;
pub const MovementAspectGroup = movement.MovementAspectGroup;
pub const MovementAspect = movement.MovementAspect;
pub const MovementKind = movement.MovementKind;
pub const BasicMovement = movement.BasicMovement;
pub const MoveIntegrator = *const fn (movement: *EMovement, delta_time_seconds: Float) bool;

pub const SimpleStepIntegrator = movement.SimpleStepIntegrator;
pub const VerletIntegrator = movement.VerletIntegrator;
pub const EulerIntegrator = movement.EulerIntegrator;

pub const AudioPlayer = audio.AudioPlayer;
pub const Sound = audio.Sound;
pub const Music = audio.Music;

pub const ContactBounds = contact.ContactBounds;
pub const Contact = contact.Contact;
pub const ContactScan = contact.ContactScan;
pub const EContact = contact.EContact;
pub const EContactScan = contact.EContactScan;
pub const ContactConstraint = contact.ContactConstraint;
pub const IContactMap = contact.IContactMap;
pub const ContactTypeAspectGroup = contact.ContactTypeAspectGroup;
pub const ContactTypeAspect = contact.ContactTypeAspect;
pub const ContactTypeKind = contact.ContactTypeKind;
pub const BasicContactTypes = contact.BasicContactTypes;
pub const ContactMaterialAspectGroup = contact.ContactMaterialAspectGroup;
pub const ContactMaterialAspect = contact.ContactMaterialAspect;
pub const ContactMaterialKind = contact.ContactMaterialKind;
pub const BasicContactMaterials = contact.BasicContactMaterials;
pub const DebugCollisionResolver = contact.DebugCollisionResolver;
pub const addDummyContactMap = contact.addDummyContactMap;

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
    // TODO

}

pub fn deinit() void {
    defer initialized = false;
    if (!initialized)
        return;

    animation.deinit();
    movement.deinit();
    audio.deinit();
    contact.deinit();
    // TODO
}
