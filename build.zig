const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("zig-cli", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("src/tests.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    // const example_step = b.step("examples", "Build examples");
    const simple = b.addExecutable("simple", "example/simple.zig");
    simple.addPackagePath("zig-cli", "src/main.zig");
    simple.setBuildMode(mode);
    simple.install();

    const short = b.addExecutable("short", "example/short.zig");
    short.addPackagePath("zig-cli", "src/main.zig");
    short.setBuildMode(mode);
    short.install();

    b.default_step.dependOn(&simple.step);
}
