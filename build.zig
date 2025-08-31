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
        .root_module = lib_mod,
    });
    const run_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);

    // Example simple
    {
        const simple_mod = b.addModule("simple", .{
            .root_source_file = b.path("examples/simple.zig"),
            .target = target,
            .optimize = optimize,
        });

        const simple = b.addExecutable(.{
            .name = "simple",
            .root_module = simple_mod,
        });
        simple.root_module.addImport("cli", lib_mod);
        b.installArtifact(simple);
        b.default_step.dependOn(&simple.step);
    }

    // Examples short
    {
        const short_mod = b.addModule("simple", .{
            .root_source_file = b.path("examples/short.zig"),
            .target = target,
            .optimize = optimize,
        });

        const short = b.addExecutable(.{
            .name = "short",
            .root_module = short_mod,
        });
        short.root_module.addImport("cli", lib_mod);
        b.installArtifact(short);
        b.default_step.dependOn(&short.step);
    }

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
