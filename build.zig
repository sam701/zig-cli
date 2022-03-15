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
    const example = b.addExecutable("example", "example/simple.zig");
    example.addPackagePath("zig-cli", "src/main.zig");
    example.setBuildMode(mode);
    example.install();
    // example_step.dependOn(&example.step);

    b.default_step.dependOn(&example.step);
}
