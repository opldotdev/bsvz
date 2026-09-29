//! A real Chronicle-era spend: the Rúnar AMM pool (opldotdev/amm-poc).
//!
//! The pool's locking script executes OP_2MUL (in Rúnar's checkPreimage
//! low-S step), so it verifies only under Chronicle rules. The transactions
//! come from tests/fixtures/amm_pool_vectors.zig; go-sdk accepted each pool
//! spend under WithAfterChronicle when they were generated. Here bsvz must
//! accept every input of every fixture transaction whose previous output is
//! also a fixture with `ExecutionFlags.postChronicleBsv()` (now also the
//! default), and reject each pool spend (input 0 of the swaps and the
//! removal) under `ExecutionFlags.postGenesisBsv()` (pre-Chronicle).
const std = @import("std");
const bsvz = @import("bsvz");
const vectors = @import("fixtures/amm_pool_vectors.zig");

const interpreter = bsvz.script.interpreter;
const Transaction = bsvz.transaction.Transaction;
const ExecutionFlags = bsvz.script.context.ExecutionFlags;

const Named = struct { name: []const u8, hex: []const u8 };
const fixtures = [_]Named{
    .{ .name = "fund", .hex = vectors.fund },
    .{ .name = "token_deploy", .hex = vectors.token_deploy },
    .{ .name = "pool_deploy", .hex = vectors.pool_deploy },
    .{ .name = "swap_bsv_in", .hex = vectors.swap_bsv_in },
    .{ .name = "swap_tokens_in", .hex = vectors.swap_tokens_in },
    .{ .name = "remove_liquidity", .hex = vectors.remove_liquidity },
};
/// The fixture transactions whose input 0 spends the pool.
const pool_spends = [_][]const u8{ "swap_bsv_in", "swap_tokens_in", "remove_liquidity" };

fn isPoolSpend(name: []const u8) bool {
    for (pool_spends) |p| if (std.mem.eql(u8, p, name)) return true;
    return false;
}

test "Rúnar AMM pool spends verify under Chronicle and only under Chronicle" {
    const allocator = std.testing.allocator;

    var txs: [fixtures.len]Transaction = undefined;
    var txids: [fixtures.len][32]u8 = undefined;
    var parsed: usize = 0;
    defer for (txs[0..parsed]) |tx| tx.deinit(allocator);
    for (fixtures, 0..) |f, i| {
        txs[i] = try Transaction.parseHex(allocator, f.hex);
        parsed += 1;
        txids[i] = (try txs[i].txid(allocator)).bytes;
    }

    var checked: usize = 0;
    var pool_checked: usize = 0;
    for (fixtures, &txs) |f, *tx| {
        for (tx.inputs, 0..) |input, input_index| {
            const source = for (txids, 0..) |id, j| {
                if (std.mem.eql(u8, &id, &input.previous_outpoint.txid.bytes)) break &txs[j];
            } else continue;
            const previous_output = source.outputs[input.previous_outpoint.index];

            const with_chronicle = interpreter.verifyPrevoutOutcome(.{
                .allocator = allocator,
                .tx = tx,
                .input_index = input_index,
                .previous_output = previous_output,
                .unlocking_script = input.unlocking_script,
                .flags = ExecutionFlags.postChronicleBsv(),
            });
            if (with_chronicle != .success) {
                std.debug.print("{s} input {}: {any}\n", .{ f.name, input_index, with_chronicle });
                return error.TestUnexpectedResult;
            }
            checked += 1;

            // Flags default to post-Chronicle mainnet rules now, so exercise
            // the "without the flag" case with an explicit pre-Chronicle
            // preset instead of relying on the default.
            const without = interpreter.verifyPrevoutOutcome(.{
                .allocator = allocator,
                .tx = tx,
                .input_index = input_index,
                .previous_output = previous_output,
                .unlocking_script = input.unlocking_script,
                .flags = ExecutionFlags.postGenesisBsv(),
            });
            if (isPoolSpend(f.name) and input_index == 0) {
                // Pre-Chronicle, OP_2MUL is a disabled opcode.
                try std.testing.expectEqual(interpreter.VerificationOutcome{ .script_error = error.UnknownOpcode }, without);
                pool_checked += 1;
            } else {
                // P2PKH and token inputs need nothing from Chronicle.
                try std.testing.expectEqual(interpreter.VerificationOutcome.success, without);
            }
        }
    }
    try std.testing.expectEqual(pool_spends.len, pool_checked);
    // pool_deploy spends fund + token_deploy; each pool spend also spends at
    // least one other fixture output.
    try std.testing.expect(checked > pool_checked + 2);
    std.debug.print("amm pool: {} fixture inputs verified under Chronicle, {} pool spends rejected without it\n", .{ checked, pool_checked });
}
