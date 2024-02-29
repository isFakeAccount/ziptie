const allocPrint = std.fmt.allocPrint;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const debugPrint = std.debug.print;
const LazyPath = std.Build.LazyPath;
const runProcess = if (builtin.zig_version.minor >= 12) std.process.Child.run else std.process.Child.exec;
const std = @import("std");
const step = std.Build.Step;

/// A structure for storing python module configurations.
/// Each Python module compiles to one shared library that may consist of multiple .c and .h files.
pub const PythonModuleOptions = struct {
    /// Module Path, This path will be used when importing this module. May include packages/namespaces separated by '.'
    module_path: [:0]const u8,
    root_source_file: ?std.Build.LazyPath,
    c_source_files: []const []const u8,

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
            "ziptie python-sysconfig --include-dir",
        ) catch @panic("Failed to setup Python");
        self.python_library_dir = self.pythonOutput(
            "ziptie python-sysconfig --lib-dir",
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
            .root_source_file = if (options.root_source_file == null) null else options.root_source_file,
            .link_libc = true,
            .target = self.*.target,
            .optimize = self.*.optimization,
        });

        ext_module_lib.addIncludePath(.{ .path = self.python_include_dir });
        ext_module_lib.addRPath(LazyPath{ .path = self.*.python_include_dir });
        const flags = [_][]const u8{};
        ext_module_lib.addCSourceFiles(
            options.c_source_files,
            &flags,
        );
        ext_module_lib.linker_allow_shlib_undefined = true;

        // renaming the shared library based on target and module
        const so_file_extension = try self.getExtSuffix();
        const so_filename = try self.*.allocator.alloc(u8, short_name.len + so_file_extension.len);

        @memcpy(so_filename[0..short_name.len], short_name);
        @memcpy(so_filename[short_name.len..], so_file_extension);

        const install = b.addInstallArtifact(ext_module_lib, .{
            .dest_sub_path = so_filename,
        });
        b.getInstallStep().dependOn(&install.step);
    }

    /// Gets the shared library file extension based on the target arch, os, and abi
    fn getExtSuffix(self: *ZiptieBuildConfig) ![]const u8 {
        const alloc = self.*.allocator;
        const target_str = try allocPrint(
            alloc,
            "{s}-{s}-{s}",
            .{ @tagName(self.*.target.getCpuArch()), @tagName(self.*.target.getOsTag()), @tagName(self.*.target.getAbi()) },
        );
        const command_str = try allocPrint(
            alloc,
            "ziptie python-sysconfig --ext-suffix {s}",
            .{target_str},
        );
        defer {
            alloc.free(target_str);
            alloc.free(command_str);
        }
        return self.pythonOutput(command_str);
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
    defer allocator.free(result.stderr);
    if (result.term.Exited != 0) {
        debugPrint("Failed to execute {s}:\n{s}\n", .{ code, result.stderr });
        std.process.exit(1);
    }
    return result.stdout;
}

/// Executes a command specified by an argument vector and returns the standard output.
fn getStdOutput(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const result = try runProcess(.{ .allocator = allocator, .argv = argv });
    defer allocator.free(result.stderr);
    if (result.term.Exited != 0) {
        debugPrint("Failed to execute {any}:\n{s}\n", .{ argv, result.stderr });
        std.process.exit(1);
    }

    return result.stdout;
}
