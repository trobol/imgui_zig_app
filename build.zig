const std = @import("std");


fn getVulkanPath( allocator: std.mem.Allocator) []const u8 {
    const vk_sdk = std.process.getEnvVarOwned(allocator, "VULKAN_SDK") catch |e|
        std.debug.panic("failed to get VULKAN_SDK: {}", .{e});

    return vk_sdk;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

	const vk_sdk_path = getVulkanPath( b.allocator );
	defer b.allocator.free( vk_sdk_path );
	
	const vk_include_path = std.fmt.allocPrint( b.allocator, "{s}/Include/", .{ vk_sdk_path }) catch @panic("oom");
	defer b.allocator.free( vk_include_path );

	const vk_lib_path = std.fmt.allocPrint( b.allocator, "{s}/Lib/", .{ vk_sdk_path }) catch @panic("oom");
	defer b.allocator.free( vk_lib_path );

	const imgui_lib = b.addStaticLibrary(.{
		.name = "imgui",
		.target = target,
		.optimize = optimize
	} );
	
	imgui_lib.addIncludePath( b.path("src/") );
	imgui_lib.addIncludePath( .{ .cwd_relative = vk_include_path } );
	imgui_lib.linkLibCpp();
	imgui_lib.linkSystemLibrary( "gdi32" );
	imgui_lib.linkSystemLibrary( "dwmapi" );
	imgui_lib.addCSourceFiles(.{
		.files = &.{ 
			"external/imgui/imgui_wrapper.cpp",
			"external/imgui/imgui_impl_vulkan.cpp",
			"external/imgui/imgui_impl_win32.cpp",
			"external/imgui/imgui.cpp",
			"external/imgui/imgui_widgets.cpp",
			"external/imgui/imgui_tables.cpp",
			"external/imgui/imgui_draw.cpp",
			"external/imgui/imgui_demo.cpp",
		}
	}
	);


    const exe = b.addExecutable(.{
        .name = "imgui_zig_app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

	exe.addIncludePath( b.path("external/") );
	exe.addIncludePath( .{ .cwd_relative = vk_include_path } );
	exe.addLibraryPath( .{ .cwd_relative = vk_lib_path } );
	exe.linkSystemLibrary( "vulkan-1" );

	
	exe.linkLibrary( imgui_lib );


    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
