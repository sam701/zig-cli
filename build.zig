const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.addModule("zig-cli", .{
        .source_file = std.Build.FileSource.relative("src/main.zig"),
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
