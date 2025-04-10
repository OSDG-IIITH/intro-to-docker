const std = @import("std");

pub fn build(b: *std.Build) void {
    const mod = b.addModule("zigeg_exe", .{
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .link_libc = true,
    });
    mod.addIncludePath(b.path("./raylib/include"));
    mod.addLibraryPath(b.path("./raylib/lib"));
    mod.linkSystemLibrary("raylib", .{ .needed = true });

    const exe = b.addExecutable(.{ .name = "zigeg", .root_module = mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_check = b.addExecutable(.{ .name = "zigeg", .root_module = mod });
    const check_step = b.step("check", "Check if the executable compiles");
    check_step.dependOn(&exe_check.step);
}
