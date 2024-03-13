#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  PROJECT_NAME='Project'
else
  PROJECT_NAME=$1
fi

mkdir "$PROJECT_NAME" && cd "$PROJECT_NAME" || exit
touch build.zig
echo "generating project files..."
echo 'const std = @import("std");
const rl = @import("raylib-zig/build.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const raylib = rl.getModule(b, "raylib-zig");
    const raylib_math = rl.math.getModule(b, "raylib-zig");
    //web exports are completely separate
    if (target.result.os.tag == .emscripten) {
        const exe_lib = rl.compileForEmscripten(b, "'$PROJECT_NAME'", "src/main.zig", target, optimize);
        exe_lib.root_module.addImport("raylib", raylib);
        exe_lib.root_module.addImport("raylib-math", raylib_math);
        const raylib_artifact = rl.getRaylib(b, target, optimize);
        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        exe_lib.linkLibrary(raylib_artifact);
        const link_step = try rl.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });
        b.getInstallStep().dependOn(&link_step.step);
        const run_step = try rl.emscriptenRunStep(b);
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run '$PROJECT_NAME'");
        run_option.dependOn(&run_step.step);
        return;
    }

    const exe = b.addExecutable(.{ .name = "'$PROJECT_NAME'", .root_source_file = .{ .path = "src/main.zig" }, .optimize = optimize, .target = target });

    rl.link(b, exe, target, optimize);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raylib-math", raylib_math);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run '$PROJECT_NAME'");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(exe);
}
' >> build.zig

mkdir src
cp ../examples/core/basic_window.zig src/main.zig
cp ../build.zig.zon .
echo "cloning raylib-zig inside of project..."
git clone ../ raylib-zig --recursive
