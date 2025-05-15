const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });
    const target = b.standardTargetOptions(.{
        .default_target = norns(b) catch unreachable,
    });

    const matron = matron: {
        const matron = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        matron.addCMacro("_GNU_SOURCE", "1");
        matron.addCMacro("HAVE_ABLETON_LINK", "1");
        matron.addCMacro("VERSION_MAJOR", "2");
        matron.addCMacro("VERSION_MINOR", "9");
        matron.addCMacro("VERSION_PATCH", "1");
        matron.addCMacro("VERSION_HASH", versionHash(b));
        if (optimize != .Debug) matron.addCMacro("NORNS_RELEASE", "1");
        matron.addCSourceFiles(.{
            .files = matron_srcs,
            .flags = &.{
                "-std=gnu11",
                "-Wextra",
                "-g",
            },
        });
        const link = link: {
            const link = b.addStaticLibrary(.{
                .name = "link",
                .target = target,
                .optimize = optimize,
            });
            const t = target.result.os.tag;

            switch (t) {
                .macos => link.root_module.addCMacro("LINK_PLATFORM_MACOSX", "1"),
                .linux => link.root_module.addCMacro("LINK_PLATFORM_LINUX", "1"),
                else => @panic("OS not supported"),
            }
            link.linkLibC();
            link.linkLibCpp();
            link.addCSourceFile(.{
                .file = b.path("third-party/link/extensions/abl_link/src/abl_link.cpp"),
                .flags = &.{"-std=c++11"},
            });
            link.addIncludePath(b.path("third-party/link/extensions/abl_link/include"));
            link.addIncludePath(b.path("third-party/link/include"));
            link.addIncludePath(b.path("third-party/link/modules/asio-standalone/asio/include"));
            break :link link;
        };
        matron.addIncludePath(b.path("third-party/link/extensions/abl_link/include"));
        matron.addIncludePath(b.path("matron/src"));
        matron.addIncludePath(b.path("matron/src/device"));
        matron.addIncludePath(b.path("matron/src/hardware"));
        matron.addIncludePath(b.path("matron/src/hardware/input"));
        matron.addIncludePath(b.path("lua"));
        matron.linkSystemLibrary("m", .{});
        matron.linkSystemLibrary("pthread", .{});
        matron.linkSystemLibrary("alsa", .{});
        matron.linkSystemLibrary("libudev", .{});
        matron.linkSystemLibrary("libevdev", .{});
        matron.linkSystemLibrary("libgpiod", .{});
        matron.linkSystemLibrary("cairo", .{});
        matron.linkSystemLibrary("cairo-ft", .{});
        matron.linkSystemLibrary("lua53", .{});
        matron.linkSystemLibrary("liblo", .{});
        matron.linkSystemLibrary("nanomsg", .{});
        matron.linkSystemLibrary("avahi-compat-libdns_sd", .{});
        matron.linkSystemLibrary("sndfile", .{});
        matron.linkSystemLibrary("jack", .{});
        matron.linkSystemLibrary("monome", .{});
        matron.linkLibrary(link);
        break :matron matron;
    };
    const matron_exe = b.addExecutable(.{
        .name = "matron",
        .root_module = matron,
    });
    b.installArtifact(matron_exe);
}

fn versionHash(b: *std.Build) []const u8 {
    const output = b.run(&.{ "git", "rev-parse", "--verify", "--short", "HEAD" });
    return if (std.mem.indexOfScalar(u8, output, '\n')) |idx| output[0..idx] else output;
}

fn norns(b: *std.Build) !std.Target.Query {
    const gpa = b.allocator;
    const ZonTarget = struct {
        triple: []const u8,
        cpu: struct {
            arch: []const u8,
            name: []const u8,
            features: []const []const u8,
        },
        os: []const u8,
        abi: []const u8,
    };
    const norns_target: ZonTarget = @import("norns-target.zon");
    const cpu_features = features: {
        var list: std.ArrayListUnmanaged(u8) = .empty;
        defer list.deinit(gpa);
        const writer = list.writer(gpa);
        errdefer @panic("OOM");
        try writer.writeAll(norns_target.cpu.name);
        for (norns_target.cpu.features) |feature| {
            try writer.writeAll("+");
            try writer.writeAll(feature);
        }
        break :features try list.toOwnedSlice(gpa);
    };
    defer gpa.free(cpu_features);
    return try .parse(.{
        .arch_os_abi = norns_target.triple,
        .cpu_features = cpu_features,
    });
}

const matron_srcs: []const []const u8 = &.{
    "matron/src/osc.c",
    "matron/src/args.c",
    "matron/src/lua_eval.c",
    "matron/src/hardware/io.c",
    // "matron/src/hardware/gpio.c",
    "matron/src/hardware/input/gpio.c",
    "matron/src/hardware/screen.c",
    "matron/src/hardware/i2c.c",
    "matron/src/hardware/platform.c",
    "matron/src/hardware/battery.c",
    "matron/src/hardware/input.c",
    "matron/src/hardware/screen/ssd1322.c",
    "matron/src/hardware/stat.c",
    "matron/src/hello.c",
    "matron/src/clocks/clock_scheduler.c",
    "matron/src/clocks/clock_crow.c",
    "matron/src/clocks/clock_link.c",
    "matron/src/clocks/clock_internal.c",
    "matron/src/clocks/clock_midi.c",
    "matron/src/weaver.c",
    "matron/src/screen_results.c",
    "matron/src/metro.c",
    "matron/src/clock.c",
    "matron/src/screen_events.c",
    "matron/src/input.c",
    "matron/src/main.c",
    "matron/src/snd_file.c",
    "matron/src/config.c",
    "matron/src/device/device_list.c",
    "matron/src/device/device_serial.c",
    "matron/src/device/device_crow.c",
    "matron/src/device/device_monitor.c",
    "matron/src/device/device_hid.c",
    "matron/src/device/device_midi.c",
    "matron/src/device/device_monome.c",
    "matron/src/device/device.c",
    "matron/src/events.c",
    "matron/src/time_since.c",
    "matron/src/system_cmd.c",
    "matron/src/oracle.c",
    "matron/src/jack_client.c",
};
