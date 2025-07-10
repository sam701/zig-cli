const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lib_mod = b.addModule("cli", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "cli",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    const simple = b.addExecutable(.{
        .target = target,
        .name = "simple",
        .root_source_file = b.path("examples/simple.zig"),
        .optimize = optimize,
    });
    simple.root_module.addImport("cli", lib_mod);
    b.installArtifact(simple);
    b.default_step.dependOn(&simple.step);

    const short = b.addExecutable(.{
        .target = target,
        .name = "short",
        .root_source_file = b.path("examples/short.zig"),
        .optimize = optimize,
    });
    short.root_module.addImport("cli", lib_mod);
    b.installArtifact(short);
    b.default_step.dependOn(&short.step);

    // Docs
    {
        const install_docs = b.addInstallDirectory(.{
            .source_dir = lib.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        const docs_step = b.step("docs", "Install docs into zig-out/docs");
        docs_step.dependOn(&install_docs.step);
    }
}
