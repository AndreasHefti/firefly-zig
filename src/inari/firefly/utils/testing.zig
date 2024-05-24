const std = @import("std");

const utils = @import("utils.zig");
const String = utils.String;
const NO_NAME = utils.NO_NAME;
const StringBuffer = utils.StringBuffer;
const Vector2f = utils.Vector2f;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const EventDispatch = utils.EventDispatch;
const DynArray = utils.DynArray;
const DynIndexArray = utils.DynIndexArray;
const BitSet = utils.BitSet;
const Vector2i = utils.Vector2i;
const RectI = utils.RectI;
const RectF = utils.RectF;
const PosI = utils.PosI;

test "float to int" {
    try std.testing.expect(2 == @as(usize, @intFromFloat(@ceil(1.1))));
}

test "rectIFromRectF" {
    try std.testing.expectEqual(
        RectI{ 1, 1, 10, 10 },
        utils.rectIFromRectF(RectF{ 1, 1, 10, 10 }),
    );
    try std.testing.expectEqual(
        RectI{ 1, 1, 10, 10 },
        utils.rectIFromRectF(RectF{ 1.1, 1.2, 10, 10 }),
    );
    try std.testing.expectEqual(
        RectI{ 1, 1, 11, 11 },
        utils.rectIFromRectF(RectF{ 1, 1, 10.1, 10.1 }),
    );
}

test "StringBuffer" {
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    sb.append("Test12");
    sb.append("Test34");
    sb.print("Test{s}", .{"56"});

    const str = sb.toString();
    try std.testing.expectEqualStrings("Test12Test34Test56", str);
}

test "Events and Listeners" {
    var ED = EventDispatch([]const u8).new(std.testing.allocator);
    defer ED.deinit();

    ED.register(testlistener1);
    ED.register(testlistener2);
    ED.notify("hallo1");
    ED.notify("hallo2");

    ED.unregister(testlistener1);

    ED.notify("hallo3");
}

test "Listener insert" {
    var ED = EventDispatch([]const u8).new(std.testing.allocator);
    defer ED.deinit();

    ED.registerInsert(0, testlistener1);
    ED.registerInsert(0, testlistener1);
}

fn testlistener1(event: []const u8) void {
    const state = struct {
        var count: i8 = 0;
    };
    if (state.count == 0) {
        std.testing.expectEqualStrings("hallo1", event) catch unreachable;
        state.count += 1;
        return;
    }
    if (state.count == 1) {
        std.testing.expectEqualStrings("hallo2", event) catch unreachable;
        return;
    }
}

fn testlistener2(event: []const u8) void {
    const state = struct {
        var count: i8 = 0;
    };
    if (state.count == 0) {
        std.testing.expectEqualStrings("hallo1", event) catch unreachable;
        state.count += 1;
        return;
    }
    if (state.count == 1) {
        std.testing.expectEqualStrings("hallo2", event) catch unreachable;
        state.count += 1;
        return;
    }
    if (state.count == 2) {
        std.testing.expectEqualStrings("hallo3", event) catch unreachable;
        return;
    }
}

test "DynIndexArray initialize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.new(allocator, 10);
    defer array.deinit();

    try testing.expect(array.items.len == 0);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 0);
}

test "DynIndexArray grow one" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.new(allocator, 10);
    defer array.deinit();

    array.add(1);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 1);
    try testing.expect(array.items[0] == 1);

    array.add(2);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 2);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);

    array.set(4, 5);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == UNDEF_INDEX);
    try testing.expect(array.items[3] == UNDEF_INDEX);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);

    array.add(6);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 6);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == UNDEF_INDEX);
    try testing.expect(array.items[3] == UNDEF_INDEX);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == 6);
    try testing.expect(array.items[6] == UNDEF_INDEX);
}

test "DynIndexArray remove" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.new(allocator, 10);
    defer array.deinit();

    array.add(1);
    array.add(2);
    array.add(3);
    array.add(4);
    array.add(5);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 3);
    try testing.expect(array.items[3] == 4);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);

    array.removeFirst(3);

    try testing.expect(array.items.len == 10);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 4);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 4);
    try testing.expect(array.items[3] == 5);
    try testing.expect(array.items[4] == UNDEF_INDEX);
}

test "DynIndexArray grow" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.new(allocator, 2);
    defer array.deinit();

    array.add(1);
    array.add(2);
    array.add(3);
    array.add(4);
    array.add(5);

    try testing.expect(array.items.len == 6);
    try testing.expect(array.grow_size == 2);
    try testing.expect(array.size_pointer == 5);
    try testing.expect(array.items[0] == 1);
    try testing.expect(array.items[1] == 2);
    try testing.expect(array.items[2] == 3);
    try testing.expect(array.items[3] == 4);
    try testing.expect(array.items[4] == 5);
    try testing.expect(array.items[5] == UNDEF_INDEX);
}

test "DynArray initialize" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).new(allocator);
    defer dyn_array.deinit();
    try testing.expect(dyn_array.capacity() == 0);
    _ = dyn_array.set(1, 0);
    try testing.expect(dyn_array.capacity() == dyn_array.register.array_size);
    try testing.expect(dyn_array.get(0).?.* == 1);
    try testing.expect(dyn_array.get(1) == null);
    try testing.expect(dyn_array.get(2) == null);
}

test "DynArray scale up" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).new(allocator);
    defer dyn_array.deinit();

    _ = dyn_array.set(100, 0);

    try testing.expect(dyn_array.capacity() == dyn_array.register.array_size);

    _ = dyn_array.set(200, 200000);

    try testing.expect(dyn_array.capacity() == 200000 + dyn_array.register.array_size);
    try testing.expect(200 == dyn_array.get(200000).?.*);
    try testing.expect(null == dyn_array.get(200001));
}

test "DynArray delete" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).new(allocator);
    defer dyn_array.deinit();

    _ = dyn_array.set(100, 0);
    try testing.expect(100 == dyn_array.get(0).?.*);
    dyn_array.delete(0);
    try testing.expect(null == dyn_array.get(0));
}

test "DynArray consistency checks" {
    var dyn_array = try DynArray(i32).new(std.testing.allocator);
    defer dyn_array.deinit();

    _ = dyn_array.set(100, 0);
    _ = dyn_array.set(100, 100);
    try std.testing.expect(dyn_array.exists(0));
    try std.testing.expect(dyn_array.exists(100));
    try std.testing.expect(!dyn_array.exists(101));
    try std.testing.expect(!dyn_array.exists(2000));
}

test "DynArray use u16 as index" {
    var dyn_array = try DynArray(i32).new(std.testing.allocator);
    defer dyn_array.deinit();

    const index1: u16 = 0;

    _ = dyn_array.set(0, index1);
}

test "test ensure capacity" {
    var bitset2 = try BitSet.newEmpty(std.testing.allocator, 8);
    defer bitset2.deinit();

    bitset2.set(2);

    try std.testing.expect(!bitset2.isSet(0));
    try std.testing.expect(!bitset2.isSet(1));
    try std.testing.expect(bitset2.isSet(2));
    try std.testing.expect(!bitset2.isSet(3));
    try std.testing.expect(bitset2.capacity() == 8);

    bitset2.set(8);

    try std.testing.expect(bitset2.capacity() == 16);
    try std.testing.expect(!bitset2.isSet(7));
    try std.testing.expect(bitset2.isSet(8));
    try std.testing.expect(!bitset2.isSet(9));

    bitset2.set(1000);
    try std.testing.expect(bitset2.lengthOfMaskArray() == 16);
}

test "initialize" {
    const TEST_ASPECT_GROUP = utils.AspectGroup(struct {
        pub const name = "TestGroup";
    });

    try std.testing.expectEqualStrings("TestGroup", TEST_ASPECT_GROUP.name());
    try std.testing.expect(TEST_ASPECT_GROUP.size() == 0);

    const aspect1 = TEST_ASPECT_GROUP.getAspect("aspect1");
    try std.testing.expect(TEST_ASPECT_GROUP.size() == 1);
    try std.testing.expect(aspect1.id == 0);
    try std.testing.expectEqualStrings("aspect1", aspect1.name);

    const aspect2 = TEST_ASPECT_GROUP.getAspect("aspect2");
    try std.testing.expect(TEST_ASPECT_GROUP.size() == 2);
    try std.testing.expect(aspect2.id == 1);
    try std.testing.expectEqualStrings("aspect2", aspect2.name);
}

const GROUP_1 = struct {
    pub const name = "TestGroup1";
};
const GROUP_2 = struct {
    pub const name = "TestGroup2";
};

test "Aspect Type/Group difference" {
    const group1 = utils.AspectGroup(GROUP_1);
    const group2 = utils.AspectGroup(GROUP_2);

    const a1g1 = group1.getAspect("g1a1");
    const a2g1 = group1.getAspect("g1a2");
    const a3g1 = group1.getAspect("g1a3");

    const a1g2 = group2.getAspect("g2a1");
    const a2g2 = group2.getAspect("g2a2");
    const a3g2 = group2.getAspect("g2a3");
    const a4g2 = group2.getAspect("g2a4");

    const kind1 = group1.newKindOf(.{ a1g1, a2g1 });
    const kind2 = group1.newKindOf(.{ a3g1, a2g1 });

    const kind3 = group2.newKindOf(.{ a1g2, a2g2 });
    const kind4 = group2.newKindOf(.{ a3g2, a4g2 });

    try std.testing.expect(kind1.hasAnyAspect(kind2));
    try std.testing.expect(!kind3.hasAnyAspect(kind4));

    //const kind5 = group2.newKindOf(.{ a1g1, a4g2 });
    //_ = kind5;

    //try std.testing.expect(kind1.hasAnyAspect(kind4));

    // gives expected compile error
    //const type_a1g1 = @TypeOf(a1g1);
    //const type_a1g2 = @TypeOf(a1g2);
    //try std.testing.expect(type_a1g1 != type_a1g2);
}

test "kind" {
    const TEST_ASPECT_GROUP = utils.AspectGroup(struct {
        pub const name = "TestGroup";
    });

    const aspect1 = TEST_ASPECT_GROUP.getAspect("aspect1");
    const aspect2 = TEST_ASPECT_GROUP.getAspect("aspect2");
    const aspect3 = TEST_ASPECT_GROUP.getAspect("aspect3");
    const aspect4 = TEST_ASPECT_GROUP.getAspect("aspect4");

    var kind1 = TEST_ASPECT_GROUP.newKindOf(.{ aspect1, aspect2, aspect3 });
    var kind2 = TEST_ASPECT_GROUP.newKindOf(.{ aspect2, aspect3 });
    var kind3 = TEST_ASPECT_GROUP.newKindOf(.{aspect4});

    try std.testing.expect(kind2.isPartOf(kind1));
    try std.testing.expect(!kind1.isPartOf(kind2));

    try std.testing.expect(!kind1.isEquals(kind2));
    try std.testing.expect(!kind3.isEquals(kind2));
    try std.testing.expect(!kind3.isEquals(kind1));
    try std.testing.expect(kind1.isEquals(kind1));

    try std.testing.expect(kind1.isNotPartOf(kind3));
    try std.testing.expect(kind3.isNotPartOf(kind1));
    try std.testing.expect(!kind1.isNotPartOf(kind2));
}

// test easing
test "easing interface" {
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    const t = 0.5;
    const fac = 5;

    sb.print("Linear:       5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Linear.f(t)});
    sb.print("Quad In:      5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quad_In.f(t)});
    sb.print("Quad Out:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quad_Out.f(t)});
    sb.print("Quad InOut:   5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quad_In_Out.f(t)});
    sb.print("Cubic In:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Cubic_In.f(t)});
    sb.print("Cubic Out:    5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Cubic_Out.f(t)});
    sb.print("Cubic InOut:  5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Cubic_In_Out.f(t)});

    sb.print("Quart In:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quart_In.f(t)});
    sb.print("Quart Out:    5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quart_Out.f(t)});
    sb.print("Quart InOut:  5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quart_In_Out.f(t)});

    sb.print("Quint In:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quint_In.f(t)});
    sb.print("Quint Out:    5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quint_Out.f(t)});
    sb.print("Quint InOut:  5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Quint_In_Out.f(t)});

    sb.print("Expo In:      5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Exponential_In.f(t)});
    sb.print("Expo Out:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Exponential_Out.f(t)});
    sb.print("Expo InOut:   5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Exponential_In_Out.f(t)});

    sb.print("Sin In:       5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Sin_In.f(t)});
    sb.print("Sin Out:      5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Sin_Out.f(t)});
    sb.print("Sin InOut:    5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Sin_In_Out.f(t)});

    sb.print("Circ In:      5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Circ_In.f(t)});
    sb.print("Circ Out:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Circ_Out.f(t)});
    sb.print("Circ InOut:   5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Circ_In_Out.f(t)});

    sb.print("Back In:      5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Back_In.f(t)});
    sb.print("Back Out:     5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Back_Out.f(t)});

    sb.print("Bounce In:    5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Bounce_In.f(t)});
    sb.print("Bounce Out:   5 * f(0.5) --> {d}\n", .{fac * utils.Easing.Bounce_Out.f(t)});

    const expected =
        \\Linear:       5 * f(0.5) --> 2.5
        \\Quad In:      5 * f(0.5) --> 1.25
        \\Quad Out:     5 * f(0.5) --> 3.75
        \\Quad InOut:   5 * f(0.5) --> 2.5
        \\Cubic In:     5 * f(0.5) --> 0.625
        \\Cubic Out:    5 * f(0.5) --> 4.375
        \\Cubic InOut:  5 * f(0.5) --> 2.5
        \\Quart In:     5 * f(0.5) --> 0.3125
        \\Quart Out:    5 * f(0.5) --> 4.6875
        \\Quart InOut:  5 * f(0.5) --> 2.5
        \\Quint In:     5 * f(0.5) --> 0.15625
        \\Quint Out:    5 * f(0.5) --> 4.84375
        \\Quint InOut:  5 * f(0.5) --> 2.5
        \\Expo In:      5 * f(0.5) --> 0.15625
        \\Expo Out:     5 * f(0.5) --> 4.84375
        \\Expo InOut:   5 * f(0.5) --> 2.5
        \\Sin In:       5 * f(0.5) --> 1.4644661
        \\Sin Out:      5 * f(0.5) --> 3.535534
        \\Sin InOut:    5 * f(0.5) --> 2.5
        \\Circ In:      5 * f(0.5) --> 0.66987306
        \\Circ Out:     5 * f(0.5) --> 4.330127
        \\Circ InOut:   5 * f(0.5) --> 2.5
        \\Back In:      5 * f(0.5) --> -0.43848753
        \\Back Out:     5 * f(0.5) --> 5.4384875
        \\Bounce In:    5 * f(0.5) --> 1.171875
        \\Bounce Out:   5 * f(0.5) --> 3.828125
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

// testing vec
test "vec math" {
    var v1 = Vector2i{ 2, 3 };
    utils.normalize2i(&v1);
    try std.testing.expect(v1[0] == 0);
    try std.testing.expect(v1[1] == 1);

    var v2 = Vector2f{ 2, 3 };
    utils.normalize2f(&v2);
    try std.testing.expect(v2[0] == 0.554700195);
    try std.testing.expect(v2[1] == 0.832050323);

    // distance
    var p1 = Vector2i{ 1, 1 };
    var p2 = Vector2i{ 2, 2 };
    const dp1p2 = utils.distance2i(&p1, &p2);
    try std.testing.expect(dp1p2 == 1.4142135381698608);
}

// BitMask tests

test "Init BitMask" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Fill/Reset" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.fill();
    sb.print("{any}", .{mask});

    try mask.reset(5, 5);
    sb.print("{any}", .{mask});

    try mask.reset(15, 15);
    mask.fill();
    sb.print("{any}", .{mask});

    const expected =
        \\BitMask[10|10]
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\BitMask[5|5]
        \\  0,0,0,0,0,
        \\  0,0,0,0,0,
        \\  0,0,0,0,0,
        \\  0,0,0,0,0,
        \\  0,0,0,0,0,
        \\BitMask[15|15]
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set Bits" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setBitAt(1, 1);
    mask.setBitAt(9, 9);
    mask.setBitAt(20, 1);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,1,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,1,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectI 1" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectI(.{ 2, 2, 5, 5 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectI 2" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectI(.{ -2, -2, 5, 5 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  1,1,1,0,0,0,0,0,0,0,
        \\  1,1,1,0,0,0,0,0,0,0,
        \\  1,1,1,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectI 3" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectI(.{ 8, 0, 5, 5 }, true);
    mask.setRectI(.{ 7, 8, 5, 5 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,1,1,
        \\  0,0,0,0,0,0,0,0,1,1,
        \\  0,0,0,0,0,0,0,0,1,1,
        \\  0,0,0,0,0,0,0,0,1,1,
        \\  0,0,0,0,0,0,0,0,1,1,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,1,1,1,
        \\  0,0,0,0,0,0,0,1,1,1,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}
test "BitMask Set RectI 4" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectI(.{ 0, 0, 10, 10 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectI 5" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectI(.{ -56, 3, 100, 100 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectF 1" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectF(.{ 2.11, 2.22, 4.1, 4.00001 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Set RectF 2" {
    var mask = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setRectF(.{ -2.11, -2.22, 4.1, -4.00001 }, true);

    sb.print("{any}", .{mask});
    const expected =
        \\BitMask[10|10]
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask SetCircleI 1" {
    var mask = utils.BitMask.new(std.testing.allocator, 15, 15);
    defer mask.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask.setCircleI(.{ 7, 7, 7 }, true);
    sb.print("{any}", .{mask});

    mask.setCircleI(.{ 7, 7, 4 }, false);
    sb.print("{any}", .{mask});

    const expected =
        \\BitMask[15|15]
        \\  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,
        \\  0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        \\  0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,
        \\  0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,
        \\  0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        \\BitMask[15|15]
        \\  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        \\  0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,
        \\  0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,
        \\  0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,
        \\  0,1,1,1,1,0,0,0,0,0,1,1,1,1,0,
        \\  0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,
        \\  0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,
        \\  0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,
        \\  0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,
        \\  0,1,1,1,0,0,0,0,0,0,0,1,1,1,0,
        \\  0,1,1,1,1,0,0,0,0,0,1,1,1,1,0,
        \\  0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,
        \\  0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,
        \\  0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,
        \\  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "BitMask Intersection 1" {
    var mask1 = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask1.deinit();
    var mask2 = utils.BitMask.new(std.testing.allocator, 10, 10);
    defer mask2.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    mask2.setRectI(.{ 0, 0, 10, 1 }, true);
    mask2.setRectI(.{ 0, 0, 1, 10 }, true);
    mask2.setRectI(.{ 9, 0, 1, 10 }, true);
    mask2.setRectI(.{ 0, 9, 10, 1 }, true);

    mask1.setIntersection(mask2, .{ -5, -5 }, utils.bitOpOR);
    mask1.setIntersection(mask2, .{ 5, 5 }, utils.bitOpOR);
    mask1.setIntersection(mask2, .{ -6, 6 }, utils.bitOpOR);
    mask1.setIntersection(mask2, .{ 6, -6 }, utils.bitOpOR);

    sb.print("{any}", .{mask2});
    sb.print("{any}", .{mask1});
    const expected =
        \\BitMask[10|10]
        \\  1,1,1,1,1,1,1,1,1,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,0,0,0,0,0,0,0,0,1,
        \\  1,1,1,1,1,1,1,1,1,1,
        \\BitMask[10|10]
        \\  0,0,0,0,1,0,1,0,0,0,
        \\  0,0,0,0,1,0,1,0,0,0,
        \\  0,0,0,0,1,0,1,0,0,0,
        \\  0,0,0,0,1,0,1,1,1,1,
        \\  1,1,1,1,1,0,0,0,0,0,
        \\  0,0,0,0,0,1,1,1,1,1,
        \\  1,1,1,1,0,1,0,0,0,0,
        \\  0,0,0,1,0,1,0,0,0,0,
        \\  0,0,0,1,0,1,0,0,0,0,
        \\  0,0,0,1,0,1,0,0,0,0,
        \\
    ;

    try std.testing.expectEqualStrings(expected, sb.toString());
}

test "Strings in DynArray" {
    var listOfStrings: DynArray(String) = DynArray(String).new(std.testing.allocator) catch unreachable;
    defer listOfStrings.deinit();

    _ = listOfStrings.add("one");
    _ = listOfStrings.add("two");
    _ = listOfStrings.add("three");
    _ = listOfStrings.add("four");
    _ = listOfStrings.add("five");

    try std.testing.expect(listOfStrings.size() == 5);

    const two = listOfStrings.get(1);
    try std.testing.expectEqualStrings(two.?.*, "two");
}

const SomeType = struct { id: usize };
test "Slices in DynArray" {
    var list = try testSliceFromList();
    defer list.deinit();

    // NOTE: it seems that the slice on the heap still pointing to
    // var s2: *[]SomeType = list.get(0).?;
    // try std.testing.expect(s2.*.len == 2);
    // try std.testing.expect(s2.*[1].id == 1);
}

fn testSliceFromList() !DynArray([]SomeType) {
    var listOfSlices: DynArray([]SomeType) = DynArray([]SomeType).new(std.testing.allocator) catch unreachable;

    var sl = [_]SomeType{ .{ .id = 0 }, .{ .id = 1 } };

    _ = listOfSlices.add(sl[0..]);

    try std.testing.expect(listOfSlices.size() == 1);

    const s2: *[]SomeType = listOfSlices.get(0).?;
    try std.testing.expect(s2.*.len == 2);
    try std.testing.expect(s2.*[1].id == 1);
    return listOfSlices;
}

test "DynArray copy of struct toKampanie  heap" {
    var list: DynArray(SomeType) = DynArray(SomeType).new(std.testing.allocator) catch unreachable;
    defer list.deinit();

    const s1 = SomeType{ .id = 1 };
    var s2 = SomeType{ .id = 2 };

    _ = list.add(s1);
    _ = list.add(s2);

    const _s1 = list.get(0).?;
    var _s2 = list.get(1).?;

    try std.testing.expect(_s1.id == 1);
    try std.testing.expect(_s2.id == 2);

    s2.id = 3;

    try std.testing.expect(_s1.id == 1);
    try std.testing.expect(_s2.id == 2);

    _s2.id = 3;

    try std.testing.expect(_s2.id == 3);
    try std.testing.expect(list.get(1).?.id == 3);
}

test "intersectsRectIOffset1" {
    const pos1: PosI = .{ 10, 10 };
    const r1: RectI = .{ 0, 0, 10, 10 };

    const pos2: PosI = .{ -10, -10 };
    const r2: RectI = .{ 0, 0, 10, 10 };

    const offset: Vector2i = .{ pos1[0] - pos2[0], pos1[1] - pos2[1] };

    try std.testing.expect(utils.intersectsRectI(r1, r2));
    try std.testing.expect(!utils.intersectsRectIOffset(r1, r2, offset));
}

test "intersectsRectIOffset2" {
    const pos1: PosI = .{ 0, 0 };
    const r1: RectI = .{ 20, 20, 10, 10 };

    const pos2: PosI = .{ 25, 25 };
    const r2: RectI = .{ 0, 0, 10, 10 };

    const offset: Vector2i = .{ pos1[0] - pos2[0], pos1[1] - pos2[1] };

    try std.testing.expect(!utils.intersectsRectI(r1, r2));
    try std.testing.expect(utils.intersectsRectIOffset(r1, r2, offset));
}

test "TEMPPerformance1" {
    const start_time = std.time.microTimestamp();
    for (0..1000000) |i| {
        const v = Vector2i{ utils.usize_cint(i), 10000 };
        _ = testTEMPPerformance(v);
    }
    const end_time = std.time.microTimestamp();
    std.debug.print("took: {d} ", .{end_time - start_time});
}

var temp_v = Vector2i{ 0, 0 };
test "TEMPPerformance2" {
    const start_time = std.time.microTimestamp();
    for (0..1000000) |i| {
        temp_v[0] = utils.usize_cint(i);
        temp_v[1] = 10000;
        _ = testTEMPPerformance(temp_v);
    }
    const end_time = std.time.microTimestamp();
    std.debug.print("took: {d} ", .{end_time - start_time});
}

fn testTEMPPerformance(v: Vector2i) bool {
    return v[0] - v[1] > 0;
}

fn Memo(comptime num: usize) type {
    return struct {
        const Self = @This();
        number: usize = num,
    };
}
test "memo test" {
    const memo1 = Memo(0);
    const memo2 = Memo(1);
    const memoinst1 = memo1{};

    try std.testing.expect(memoinst1.number == 0);
    try std.testing.expect(memo1 != memo2);
}

test "DynIndexMap" {
    var map = utils.DynIndexMap.new(std.testing.allocator);
    defer map.deinit();
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    map.map(3, 3);
    map.map(2, 1);
    map.map(3, 4);
    map.map(4, 5);
    map.map(100, 6);
    map.map(3, 32);
    map.map(2, 13);
    map.map(3, 44);
    map.map(4, 55);
    map.map(100, 66);

    sb.print("{any}", .{map});
    try std.testing.expectEqualStrings(
        "DynIndexMap[ 4=5,55 100=6,66 2=1,13 3=3,4,32,44 ]",
        sb.toString(),
    );

    sb.clear();
    map.remove(3, 4);
    sb.print("{any}", .{map});
    try std.testing.expectEqualStrings(
        "DynIndexMap[ 4=5,55 100=6,66 2=1,13 3=3,32,44 ]",
        sb.toString(),
    );

    sb.clear();
    map.removeAll(2);
    sb.print("{any}", .{map});
    try std.testing.expectEqualStrings(
        "DynIndexMap[ 4=5,55 100=6,66 3=3,32,44 ]",
        sb.toString(),
    );
}
