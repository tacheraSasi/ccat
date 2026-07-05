const std = @import("std");
const builtin = @import("builtin");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    // Get arguments via the new Init API
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    if (args.len < 2) {
        try printer(io, "Usage: {s} <file_path>\n", .{args[0]});
        return;
    }

    const filePath = args[1];

    // Open file
    const file = std.Io.Dir.cwd().openFile(io, filePath, .{ .mode = .read_only }) catch |err| {
        switch (err) {
            error.FileNotFound => try printErr(io, "Error: File not found: {s}\n", .{filePath}),
            error.AccessDenied => try printErr(io, "Error: Permission denied: {s}\n", .{filePath}),
            error.IsDir => try printErr(io, "Error: '{s}' is a directory, not a file.\n", .{filePath}),
            else => try printErr(io, "Error: Could not open '{s}': {s}\n", .{ filePath, @errorName(err) }),
        }
        return;
    };
    defer file.close(io);

    const stat = try file.stat(io);
    const file_size = stat.size;

    if (file_size == 0) {
        try printErr(io, "Error: File '{s}' is empty, nothing to copy.\n", .{filePath});
        return;
    }

    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);

    const bytesRead = try file.readPositionalAll(io, buffer, 0);
    try copy(io, buffer[0..bytesRead]);
}

fn copy(io: std.Io, content: []const u8) !void {
    const clipboard_cmd = switch (builtin.os.tag) {
        .macos => "pbcopy",
        .linux => blk: {
            if (isCommandAvailable(io, "wl-copy")) {
                break :blk "wl-copy";
            }
            if (isCommandAvailable(io, "xclip")) {
                break :blk "xclip -selection clipboard";
            }
            try printErr(io, "Error: No clipboard tool found. Install 'xclip' or 'wl-copy'.\n", .{});
            return error.NoClipboardTool;
        },
        else => {
            try printErr(io, "Error: Unsupported operating system.\n", .{});
            return error.UnsupportedOS;
        },
    };

    var child = try std.process.spawn(io, .{
        .argv = &[_][]const u8{clipboard_cmd},
        .stdin = .pipe,
    });

    try child.stdin.?.writeStreamingAll(io, content);
    child.stdin.?.close(io);
    child.stdin = null;

    _ = try child.wait(io);
    try printer(io, "Copied\n", .{});
}

fn isCommandAvailable(io: std.Io, cmd: []const u8) bool {
    var child = std.process.spawn(io, .{
        .argv = &[_][]const u8{ "which", cmd },
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch return false;
    const term = child.wait(io) catch return false;
    return switch (term) {
        .Exited => |code| code == 0,
        else => false,
    };
}

fn printer(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}

fn printErr(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buf);
    const stderr = &writer.interface;
    try stderr.print(fmt, args);
    try stderr.flush();
}
