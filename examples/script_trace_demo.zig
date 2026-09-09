const std = @import("std");
const bsvz = @import("bsvz");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var traced = bsvz.script.thread.verifyScriptsTraced(.{
        .allocator = allocator,
    }, bsvz.script.Script.init(&[_]u8{}), bsvz.script.Script.init(&[_]u8{
        @intFromEnum(bsvz.script.opcode.Opcode.OP_1),
        @intFromEnum(bsvz.script.opcode.Opcode.OP_FROMALTSTACK),
    }));
    defer traced.deinit(allocator);

    var threaded = std.Io.Threaded.init(allocator, .{ .environ = .empty });
    defer threaded.deinit();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(threaded.io(), &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try traced.writeDebug(stdout);
    try stdout.writeByte('\n');
    try stdout.flush();
}
