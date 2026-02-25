const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const ccat = @import("ccat");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const cwd = fs.cwd();
    const file_open_flags = fs.File.OpenFlags{ .mode = .read_only };
    const args = std.process.argsAlloc(allocator) catch {
        try printer("Failed to allocate memory for arguments.\n", .{});
        return;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printer("Usage: {s} <file_path>\n", .{args[0]});
        return;
    }
    const filePath = if (args.len > 1) args[1] else unreachable;

    const file = try cwd.openFile(filePath, file_open_flags);
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const buffer = allocator.alloc(u8, file_size) catch {
        try printer("Failed to allocate memory for file buffer.\n", .{});
        return;
    };
    defer allocator.free(buffer);

    const bytesRead = try file.read(buffer);

    const stdout_file = std.fs.File.stdout();
    try stdout_file.writeAll(buffer[0..bytesRead]);
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
            return error.NoClipboardTool;
        },
        else => return error.UnsupportedOS,
    };

    var process = std.process.Child.init(&[_][]const u8{clipboard_cmd}, allocator);
    process.stdin_behavior = .Pipe;

    try process.spawn();

    try process.stdin.?.writeAll(content);
    process.stdin.?.close();
    process.stdin = null;

    _ = try process.wait();

    try printer("Copied: {s}\n", .{content});
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
