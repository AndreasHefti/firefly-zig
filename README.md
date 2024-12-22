# firefly-zig

Firefly is a 2D Game API and engine strongly based on ECS design. Uses [raylib](https://github.com/raysan5/raylib) under the hood 

Note: Firefly is under heavy development and way far from release or completed feature set. 

TODO: 

    - [x] Autoscaling on Window size changes
    - [ ] Game Controller example
    - [x] Next Release

Features:

    - [x] utils - geometry utilities
    - [x] utils - DynArray, DynIndexArray and DynIndexMap for index mapping
    - [x] utils - Event and EventDispatcher for define and using events
    - [x] utils - Aspects, Aspect Groups and Kind (TODO Aspects Mixin?)
    - [x] utils - Bitset and Bit-Mask

    - [x] api - NamePool to store arbitrary names on the heap
    - [x] api - Components, Entities/Components, Systems (with Mixins)
    - [x] api - Attributes Component and CallContext (with Mixins)
    - [x] api - Composite Component(with Mixin)
    - [x] api - Assets Component (with Mixin)
    - [x] api - Control Component (with Mixin)
    - [x] api - Trigger Component
    - [x] api - Task Component
    - [x] api - State Engine Component
    - [x] api - State Engine and Entity State Engine Components

    - [x] graphics - Shader
    - [x] graphics - Texture Asset
    - [x] graphics - View and Layer Components
    - [x] graphics - Transform Entity Component
    - [x] graphics - Sprites Entity Component
    - [x] graphics - Tiles and TileMap Component
    - [x] graphics - Text Entity Component
    - [x] graphics - Shapes Entity Component

    - [x] physics - Animation
    - [x] physics - Movement 
    - [x] physics - Collision-Detection
    - [x] physics - Collision-Resolving
    - [ ] physics - Ray-Cast
    - [x] physics - Audio
    
    - [x] game - Behavior 
    - [x] game - TileSet (created in code or loaded from JSON file)
    - [x] game - TileMap (created in code or loaded from JSON file)
    - [x] game - Camera (simple pivot camera)
    - [x] game - Player 
    - [x] game - Platformer - Jump / Move Control and Collision Resolver
    - [x] game - Platformer - Area (created in code or loaded from JSON file)
    - [x] game - Platformer - Room (created in code or loaded from JSON file)
    - [x] game - Adaptable main View that fits to different screens without losing resolution


 ## Code Example:

![](inari.gif)

``` zig
_ = Texture.Component.newActive(.{
    .name = "TestTexture",
    .resource = "resources/logo.png",
    .is_mipmap = false,
});

const sprite_id = SpriteTemplate.Component.new(.{
    .texture_name = "TestTexture",
    .texture_bounds = utils.RectF{ 0, 0, 32, 32 },
});

_ = Entity.newActive(.{ .name = "TestEntity" }, .{
        ETransform{
            .position = .{ 64, 164 },
            .scale = .{ 4, 4 },
            .pivot = .{ 16, 16 },
            .rotation = 180,
        },
        ESprite{ .template_id = sprite_id },
        EEasingAnimation{
            .duration = 1000,
            .looping = true,
            .inverse_on_loop = true,
            .active_on_init = true,
            .loop_callback = loopCallback1,
            .start_value = 164.0,
            .end_value = 264.0,
            .easing = Easing.Linear,
            .property_ref = ETransform.Property.XPos,
        },
        EEasingAnimation{
            .duration = 2000,
            .looping = true,
            .inverse_on_loop = true,
            .active_on_init = true,
            .start_value = 0.0,
            .end_value = 180.0,
            .easing = Easing.Linear,
            .property_ref = ETransform.Property.Rotation,
        },
    });
```

 ## Platformer essentials and Room loading from JSON file now working:

 ![](platformer.gif)


 ## Usage / Setup

   - Install latest Zig (0.13) from https://ziglang.org/
   - create working directory and and use :zig init to initialize a zig project

# With VS Code

    - Install and open VS code
    - Install newest Zig Language plugin and C/C++ Plugin for debugging if needed
    - Open the created directory in VS code
    - Create .vscode directory if it not yet exists and create the following tasks.json and launch.json files:

tasks.json
``` 
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "zig build",
            "type": "shell",
            "command": "zig",
            "args": [
                "build",
                "--summary",
                "all"
            ],
            "options": {
                "cwd": "${workspaceRoot}"
            },
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": true,
                "clear": false
            },
            "problemMatcher": [],
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
    ]
}
```

launch.json, "firefly-zig-example" refer to the resulting exe
```
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "cppvsdbg",
            "request": "launch",
            "name": "Debug",
            "program": "${workspaceFolder}/zig-out/bin/firefly-zig-example",
            "args": ["freference-trace"], 
            "cwd": "${workspaceFolder}",
            "preLaunchTask": "zig build",
        },
    ]
}
```

#Zig Build

  - In the root directory add the following build.zig.zon file or edit the existing if available. This declares the needed dependencies which are raylib and firefly.

```
.{
    .name = "firefly-zig-example",
    .version = "0.0.1",
    .dependencies = .{
        .raylib = .{
            .url = "https://github.com/raysan5/raylib/archive/57b5f11e2a2595ea189fae03d41c8b1c194c8dfa.tar.gz",
            .hash = "1220449c6998951906efc8c7be4bb80c270f05d0911408524a8a418bf127bfa863eb",
        },
        .firefly = .{
            .url = "https://github.com/AndreasHefti/firefly-zig/archive/b5bd8866bf022834b9a059069f5266b5efe1e499.tar.gz",
            .hash = "1220f497a8e9b7a2128fb59d0c467aaf8e2711a24312535961c74b400cfa7193e826",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

  - Edit the created build.zig fine accordingly:

```
const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.Debug;

    // use raylib dependency
    const raylib_dep = b.dependency("raylib", .{
        .target = target,
    });

    // use firefly dependency
    const firefly_dep = b.dependency("firefly", .{
        .target = target,
    });

    // use firefly as module
    const firefly_module = firefly_dep.module("firefly");
    // we link the raylib dependency here to the firefly module
    firefly_module.linkLibrary(raylib_dep.artifact("raylib"));

    // build executable
    const exe = b.addExecutable(.{
        .name = "firefly-zig-example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("firefly", firefly_module);
    exe.linkLibrary(firefly_dep.artifact("firefly"));
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

The you are ready to start coding, have fun! Hello Firefly example:

```
const std = @import("std");
const firefly = @import("firefly");
const api = firefly.api;
const graphics = firefly.graphics;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    try firefly.init(.{
        .allocator = allocator,
        .entity_allocator = allocator,
        .component_allocator = allocator,
    });
    defer firefly.deinit();

    firefly.Engine.start(800, 200, 60, "Hello Firefly", init);
}

pub fn init() void {
    _ = api.Entity.newActive(.{}, .{
        graphics.ETransform{
            .position = .{ 100, 50 },
        },
        graphics.EText{
            .tint_color = .{ 200, 0, 0, 255 },
            .size = 100,
            .text = "Hello Firefly",
        },
    });
}
```

  - Firefly and Windows setup is done within the main method. 
  - Then start the firefly engine with Windows details.
  - The init method that is given as callback for the Engine start, will be called from the Engine and creates just a text entity that gets rendered on screen.