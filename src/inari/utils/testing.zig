const std = @import("std");

const utils = @import("utils.zig");
const StringBuffer = utils.StringBuffer;
const Vector2f = utils.Vector2f;
const UNDEF_INDEX = utils.UNDEF_INDEX;
const EventDispatch = utils.EventDispatch;
const DynArray = utils.DynArray;
const DynIndexArray = utils.DynIndexArray;
const BitSet = utils.BitSet;
const Kind = utils.Kind;

test "StringBuffer" {
    var sb = StringBuffer.init(std.testing.allocator);
    defer sb.deinit();

    sb.append("Test12");
    sb.append("Test34");
    sb.print("Test{s}", .{"56"});

    var str = sb.toString();
    try std.testing.expectEqualStrings("Test12Test34Test56", str);
}

test "repl test" {
    var v = getReadwrite();
    v[0] = 0;
}

var v1: utils.Vector2f = Vector2f{ 0, 0 };
pub fn getReadonly() *const Vector2f {
    return &v1;
}

pub fn getReadwrite() *Vector2f {
    return &v1;
}

test "Events and Listeners" {
    var ED = EventDispatch([]const u8).init(std.testing.allocator);
    defer ED.deinit();

    ED.register(testlistener1);
    ED.register(testlistener2);
    ED.notify("hallo1");
    ED.notify("hallo2");

    ED.unregister(testlistener1);

    ED.notify("hallo3");
}

test "Listener insert" {
    var ED = EventDispatch([]const u8).init(std.testing.allocator);
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

    var array = DynIndexArray.init(allocator, 10);
    defer array.deinit();

    try testing.expect(array.items.len == 0);
    try testing.expect(array.grow_size == 10);
    try testing.expect(array.size_pointer == 0);
}

test "DynIndexArray grow one" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var array = DynIndexArray.init(allocator, 10);
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

    var array = DynIndexArray.init(allocator, 10);
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

    var array = DynIndexArray.init(allocator, 2);
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

    var dyn_array = try DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();
    try testing.expect(dyn_array.size() == 0);
    dyn_array.set(1, 0);
    try testing.expect(dyn_array.size() == dyn_array.register.array_size);
    try testing.expect(dyn_array.get(0).* == 1);
    try testing.expect(dyn_array.get(1).* == -1);
    try testing.expect(dyn_array.get(2).* == -1);
}

test "DynArray scale up" {
    const allocator = std.testing.allocator;
    const testing = std.testing;

    var dyn_array = try DynArray(i32).init(allocator, -1);
    defer dyn_array.deinit();

    dyn_array.set(100, 0);

    try testing.expect(dyn_array.size() == dyn_array.register.array_size);

    dyn_array.set(200, 200000);

    try testing.expect(dyn_array.size() == 200000 + dyn_array.register.array_size);
    try testing.expect(200 == dyn_array.get(200000).*);
    try testing.expect(-1 == dyn_array.get(200001).*);
}

test "DynArray consistency checks" {
    var dyn_array = try DynArray(i32).init(std.testing.allocator, -1);
    defer dyn_array.deinit();

    try std.testing.expect(-1 == dyn_array.null_value);
    dyn_array.set(100, 0);
    dyn_array.set(100, 100);
    try std.testing.expect(dyn_array.exists(0));
    try std.testing.expect(dyn_array.exists(100));
    try std.testing.expect(!dyn_array.exists(101));
    try std.testing.expect(!dyn_array.exists(2000));
}

test "DynArray use u16 as index" {
    var dyn_array = try DynArray(i32).init(std.testing.allocator, -1);
    defer dyn_array.deinit();

    const index1: u16 = 0;

    dyn_array.set(0, index1);
}

test "test ensure capacity" {
    var bitset2 = try BitSet.initEmpty(std.testing.allocator, 8);
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
}

test "initialize" {
    try utils.init(std.testing.allocator);
    defer utils.deinit();

    var groupPtr = try utils.AspectGroup.new("TestGroup");
    try std.testing.expectEqualStrings("TestGroup", groupPtr.name);
    try std.testing.expect(groupPtr._size == 0);

    var aspect1Ptr = groupPtr.getAspect("aspect1");
    try std.testing.expect(groupPtr._size == 1);
    try std.testing.expect(aspect1Ptr.group == groupPtr);
    try std.testing.expect(aspect1Ptr.index == 0);
    try std.testing.expectEqualStrings("aspect1", aspect1Ptr.name);

    var aspect2Ptr = groupPtr.getAspect("aspect2");
    try std.testing.expect(groupPtr._size == 2);
    try std.testing.expect(aspect2Ptr.group == groupPtr);
    try std.testing.expect(aspect2Ptr.index == 1);
    try std.testing.expectEqualStrings("aspect2", aspect2Ptr.name);
}

test "kind" {
    try utils.init(std.testing.allocator);
    defer utils.deinit();

    var groupPtr = try utils.AspectGroup.new("TestGroup");
    var aspect1Ptr = groupPtr.getAspect("aspect1");
    var aspect2Ptr = groupPtr.getAspect("aspect2");
    var aspect3Ptr = groupPtr.getAspect("aspect3");
    var aspect4Ptr = groupPtr.getAspect("aspect4");

    var kind1 = Kind.of(aspect1Ptr).with(aspect2Ptr).with(aspect3Ptr);
    var kind2 = Kind.of(aspect2Ptr).with(aspect3Ptr);
    var kind3 = Kind.of(aspect4Ptr);

    try std.testing.expect(kind2.isKindOf(&kind1));
    try std.testing.expect(!kind1.isKindOf(&kind2));
    try std.testing.expect(kind1.isOfKind(&kind2));
    try std.testing.expect(!kind1.isExactKindOf(&kind2));
    try std.testing.expect(!kind3.isExactKindOf(&kind2));
    try std.testing.expect(!kind3.isExactKindOf(&kind1));
}
