const std = @import("std");

const zig011 = @hasDecl(std, "Build");
const Bb = if (zig011) std.Build else std.build.Builder;

pub fn build(b: *Bb) void {
    if (zig011)
        build_011(b)
    else
        build_010(b);
}

pub fn build_010(b: *Bb) void {
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
    b.default_step.dependOn(&short.step);
}

pub fn build_011(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.createModule(.{
        .source_file = .{ .path = "src/main.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "zig-cli",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const simple = b.addExecutable(.{
        .name = "simple",
        .root_source_file = .{ .path = "example/simple.zig" },
        .optimize = optimize,
    });
    simple.addModule("zig-cli", module);
    b.installArtifact(simple);

    const short = b.addExecutable(.{
        .name = "short",
        .root_source_file = .{ .path = "example/short.zig" },
        .optimize = optimize,
    });
    short.addModule("zig-cli", module);
    b.installArtifact(short);

    b.default_step.dependOn(&simple.step);
    b.default_step.dependOn(&short.step);
}
