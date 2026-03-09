const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const ccat = @import("ccat");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const cwd = fs.cwd();
    const file_open_flags = fs.File.OpenFlags{ .mode = .read_only };
    const args = std.process.argsAlloc(allocator) catch {
        try printErr("Failed to allocate memory for arguments.\n", .{});
        return;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printer("Usage: {s} <file_path>\n", .{args[0]});
        return;
    }
    const filePath = if (args.len > 1) args[1] else unreachable;

    const file = cwd.openFile(filePath, file_open_flags) catch |err| {
        switch (err) {
            error.FileNotFound => try printErr("Error: File not found: {s}\n", .{filePath}),
            error.AccessDenied => try printErr("Error: Permission denied: {s}\n", .{filePath}),
            error.IsDir => try printErr("Error: '{s}' is a directory, not a file.\n", .{filePath}),
            else => try printErr("Error: Could not open '{s}': {s}\n", .{ filePath, @errorName(err) }),
        }
        return;
    };
    defer file.close();

    const stat = file.stat() catch |err| {
        try printErr("Error: Could not read file metadata for '{s}': {s}\n", .{ filePath, @errorName(err) });
        return;
    };
    const file_size = stat.size;

    if (file_size == 0) {
        try printErr("Error: File '{s}' is empty, nothing to copy.\n", .{filePath});
        return;
    }

    const buffer = allocator.alloc(u8, file_size) catch {
        try printErr("Error: Failed to allocate memory for file buffer ({d} bytes).\n", .{file_size});
        return;
    };
    defer allocator.free(buffer);

    const bytesRead = file.read(buffer) catch |err| {
        try printErr("Error: Failed to read '{s}': {s}\n", .{ filePath, @errorName(err) });
        return;
    };

    copy(allocator, buffer[0..bytesRead]) catch |err| {
        try printErr("Error: Failed to copy to clipboard: {s}\n", .{@errorName(err)});
        return;
    };
}

fn copy(allocator: std.mem.Allocator, content: []const u8) !void {
    const clipboard_cmd = switch (builtin.os.tag) {
        .macos => "pbcopy",
        .linux => blk: {
            if (isCommandAvailable(allocator, "wl-copy")) {
                break :blk "wl-copy";
            }
            if (isCommandAvailable(allocator, "xclip")) {
                break :blk "xclip -selection clipboard";
            }
            try printErr("Error: No clipboard tool found. Install 'xclip' or 'wl-copy'.\n", .{});
            return error.NoClipboardTool;
        },
        else => {
            try printErr("Error: Unsupported operating system.\n", .{});
            return error.UnsupportedOS;
        },
    };

    var process = std.process.Child.init(&[_][]const u8{clipboard_cmd}, allocator);
    process.stdin_behavior = .Pipe;

    try process.spawn();

    try process.stdin.?.writeAll(content);
    process.stdin.?.close();
    process.stdin = null;

    _ = try process.wait();

    try printer("Copied\n", .{});
}

fn isCommandAvailable(allocator: std.mem.Allocator, cmd: []const u8) bool {
    var process = std.process.Child.init(&[_][]const u8{ "which", cmd }, allocator);
    process.stdout_behavior = .Ignore;
    process.stderr_behavior = .Ignore;
    const result = process.spawnAndWait() catch return false;
    return result.Exited == 0;
}

fn printer(comptime fmt: []const u8, arg: anytype) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;
    try stdout.print(fmt, arg);
    try stdout.flush();
}

fn printErr(comptime fmt: []const u8, arg: anytype) !void {
    var stderr_buf: [1024]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr: *std.io.Writer = &stderr_writer.interface;
    try stderr.print(fmt, arg);
    try stderr.flush();
}
