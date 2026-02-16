const std = @import("std");
const ccat = @import("ccat");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = std.process.argsAlloc(allocator) catch {
        std.debug.print("Failed to allocate memory for arguments.\n", .{});
        return;
    };
    defer std.process.argsFree(allocator, args);

    const filePath = if (args.len > 1) args[1] else unreachable;

    const file = try std.fs.cwd().openFile(filePath, .{ .mode = .read_only });
    defer file.close();

    const file_content = try file.reader(std.math.maxInt(usize)).readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_content);

    try printer(file_content);
}

fn printer(message: []const u8) !void {
    var stdout_buf: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout: *std.io.Writer = &stdout_writer.interface;
    try stdout.writeAll(message);
    try stdout.flush();
}
