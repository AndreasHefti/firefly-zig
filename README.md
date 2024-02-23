# firefly-zig

TODO:

- Better duck-typing in Components, Systems and Events by declaring expected functions references globally within the namespace and use this declarations as types as well as for comptime checks like: 

    ``
    if (@TypeOf(Self.read) != fn(*Self, []const u8) ReadError!usize) {
        error handling...
    }
    ``

- Create utils and firefly global namespace API declarations that can be used for easy import and that declares all sub-name spaces (modules) and all main types on the same level. Check if usingnamespace can be used to import them without the need of a prefix. https://ziglang.org/documentation/master/#usingnamespace
