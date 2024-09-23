const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "blog",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize
    });

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize
    });
    exe.root_module.addImport("httpz", httpz.module("httpz"));

    b.installArtifact(exe);
}