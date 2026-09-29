const std = @import("std");
const bsvz = @import("bsvz");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var tx = bsvz.transaction.Transaction{
        .version = 2,
        .inputs = &[_]bsvz.transaction.Input{
            .{
                .previous_outpoint = .{
                    .txid = .{ .bytes = @as([32]u8, @splat(0)) },
                    .index = 0,
                },
                .unlocking_script = bsvz.script.Script.init(&[_]u8{}),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]bsvz.transaction.Output{
            .{
                .satoshis = 1,
                .locking_script = bsvz.script.Script.init(&[_]u8{
                    @intFromEnum(bsvz.script.opcode.Opcode.OP_0),
                }),
            },
        },
        .lock_time = 0,
    };

    var traced = bsvz.script.interpreter.verifyPrevoutTraced(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_output = tx.outputs[0],
        .unlocking_script = tx.inputs[0].unlocking_script,
    });
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
