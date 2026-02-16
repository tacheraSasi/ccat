const std = @import("std");
const ccat = @import("ccat");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args =  std.process.argsAlloc(allocator) catch {
        std.debug.print("Failed to allocate memory for arguments.\n", .{});
        return;
    };
    defer std.process.argsFree(allocator, args);
    
}
