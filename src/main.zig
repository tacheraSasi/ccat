const std = @import("std");
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

    const filePath = if (args.len > 1) args[1] else unreachable;

    const file = try cwd.openFile(filePath, file_open_flags);
    defer file.close();

    const buffer_size = std.math.maxInt(usize);
    const buffer = allocator.alloc(u8, buffer_size) catch {
        try printer("Failed to allocate memory for file buffer.\n", .{});
        return;
    };

    const bytesRead = try file.read(buffer);
    defer allocator.free(buffer);

    try printer("Read {} bytes from file '{}'.\n", .{bytesRead, filePath});

}

fn printer(comptime fmt: []const u8, arg: anytype) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;
    try stdout.print(fmt, .{arg});
    try stdout.flush();
}
