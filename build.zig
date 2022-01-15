const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = b.addStaticLibrary("xml", "src/lib.zig");
    lib.setBuildMode(mode);
    lib.install();

    const main_tests = b.addTest("test/index.zig");
    main_tests.setBuildMode(mode);
    main_tests.addPackagePath("xml", "src/lib.zig");
    main_tests.linkLibC();
    main_tests.linkSystemLibrary("ixml");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
