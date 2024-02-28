const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const LazyPath = std.Build.LazyPath;
const debugPrint = std.debug.print;
const std = @import("std");
const step = std.Build.Step;
const runProcess = if (builtin.zig_version.minor >= 12) std.process.Child.run else std.process.Child.exec;

/// A structure for storing python module configurations.
/// Each Python module compiles to one shared library that may consist of multiple .c and .h files.
pub const PythonModuleOptions = struct {
    /// Module Path, This path will be used when importing this module. May include packages/namespaces separated by '.'
    module_path: [:0]const u8,
    root_source_file: std.Build.LazyPath,

    /// Returns the module name string that will be used to generate filename for the shared library.
    /// Note: This does not include the extension name. That is determined separately based on target os.
    pub fn moduleName(self: *const PythonModuleOptions) [:0]const u8 {
        if (std.mem.lastIndexOfScalar(u8, self.module_path, '.')) |module_name_idx| {
            return self.module_path[module_name_idx + 1 .. :0];
        }
        return self.module_path;
    }
};

pub const ZiptieBuildConfig = struct {
    allocator: std.mem.Allocator,
    build: *std.Build,
    optimization: std.builtin.Mode,
    target: std.zig.CrossTarget,
    limited_api: bool,

    python_exe: []const u8,
    python_include_dir: []const u8,
    python_library_dir: []const u8,

    pub fn init(
        b: *std.Build,
        optimization: std.builtin.Mode,
        target: std.zig.CrossTarget,
        limited_api: bool,
        python_exe: []const u8,
    ) *ZiptieBuildConfig {
        var self = b.allocator.create(ZiptieBuildConfig) catch @panic("OOM");
        self.* = .{
            .allocator = b.allocator,
            .build = b,
            .optimization = optimization,
            .target = target,
            .limited_api = limited_api,
            .python_exe = python_exe,
            .python_include_dir = "",
            .python_library_dir = "",
        };

        self.python_include_dir = self.pythonOutput(
            "import sysconfig; print(sysconfig.get_path('include'), end='')",
        ) catch @panic("Failed to setup Python");
        self.python_library_dir = self.pythonOutput(
            "import sysconfig; print(sysconfig.get_config_var('LIBDIR'), end='')",
        ) catch @panic("Failed to setup Python");

        return self;
    }

    /// Adds the building of Python extension module to overall build process. Also, links the necessary libraries
    /// to make the build possible.
    pub fn addExtensionModule(self: *ZiptieBuildConfig, options: PythonModuleOptions) !void {
        const b = self.build;
        const short_name = options.moduleName();

        const ext_module_lib = b.addSharedLibrary(.{
            .name = short_name,
            .link_libc = true,
            .root_source_file = options.root_source_file,
            .target = self.*.target,
            .optimize = self.*.optimization,
        });

        ext_module_lib.addIncludePath(.{ .path = self.python_include_dir });
        ext_module_lib.addRPath(LazyPath{ .path = self.*.python_include_dir });
        ext_module_lib.linker_allow_shlib_undefined = true;

        const install = b.addInstallArtifact(ext_module_lib, .{
            .dest_sub_path = short_name,
        });
        debugPrint("Prefix: {s}\n", .{self.*.build.lib_dir});
        b.getInstallStep().dependOn(&install.step);
    }

    fn pythonOutput(self: *ZiptieBuildConfig, code: []const u8) ![]const u8 {
        return getPythonOutput(self.allocator, self.python_exe, code);
    }
};

/// Executes a Python code snippet using a specified Python executable and returns the standard output.
fn getPythonOutput(allocator: std.mem.Allocator, python_exe: []const u8, code: []const u8) ![]const u8 {
    const result = try runProcess(.{
        .allocator = allocator,
        .argv = &.{ python_exe, "-c", code },
    });
    if (result.term.Exited != 0) {
        debugPrint("Failed to execute {s}:\n{s}\n", .{ code, result.stderr });
        std.process.exit(1);
    }
    allocator.free(result.stderr);
    return result.stdout;
}

/// Executes a command specified by an argument vector and returns the standard output.
fn getStdOutput(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const result = try runProcess(.{ .allocator = allocator, .argv = argv });
    if (result.term.Exited != 0) {
        debugPrint("Failed to execute {any}:\n{s}\n", .{ argv, result.stderr });
        std.process.exit(1);
    }
    allocator.free(result.stderr);
    return result.stdout;
}
