const std = @import("std");
const thread = @import("thread.zig");
const Script = @import("script.zig").Script;
const Input = @import("../transaction/input.zig").Input;
const OutPoint = @import("../transaction/outpoint.zig").OutPoint;
const Output = @import("../transaction/output.zig").Output;
const Transaction = @import("../transaction/transaction.zig").Transaction;

pub const Error = thread.Error;
pub const ScriptPhase = thread.ScriptPhase;
pub const VerificationTerminal = thread.VerificationTerminal;
pub const VerificationOutcome = thread.VerificationOutcome;
pub const VerificationResult = thread.VerificationResult;
pub const TracedVerificationResult = thread.TracedVerificationResult;
pub const ExecutionContext = thread.ExecutionContext;
pub const ExecutionFlags = thread.ExecutionFlags;

pub const P2pkhSpendContext = struct {
    allocator: std.mem.Allocator,
    tx: *const Transaction,
    input_index: usize,
    previous_satoshis: i64,
    unlocking_script: Script,
    locking_script: Script,
    enable_legacy_p2sh: bool = false,
    /// Script-verification policy. Defaults to current mainnet rules
    /// (post-Chronicle, activated 7 April 2026); pass
    /// `ExecutionFlags.postGenesisBsv()` to opt out and verify a
    /// pre-Chronicle script instead.
    flags: ExecutionFlags = .{},

    fn executionContext(ctx: P2pkhSpendContext) ExecutionContext {
        var result = ExecutionContext.forSpend(ctx.allocator, ctx.tx, ctx.input_index, ctx.previous_satoshis);
        result.flags = ctx.flags;
        return result;
    }
};

pub const PrevoutSpendContext = struct {
    allocator: std.mem.Allocator,
    tx: *const Transaction,
    input_index: usize,
    previous_output: Output,
    unlocking_script: Script,
    enable_legacy_p2sh: bool = false,
    /// Script-verification policy. Defaults to current mainnet rules
    /// (post-Chronicle, activated 7 April 2026); pass
    /// `ExecutionFlags.postGenesisBsv()` to opt out and verify a
    /// pre-Chronicle script instead.
    flags: ExecutionFlags = .{},

    fn executionContext(ctx: PrevoutSpendContext) ExecutionContext {
        var result = ExecutionContext.forPrevoutSpend(ctx.allocator, ctx.tx, ctx.input_index, ctx.previous_output);
        result.flags = ctx.flags;
        return result;
    }
};

pub fn verify(ctx: P2pkhSpendContext) Error!bool {
    var result = verifyDetailed(ctx);
    defer result.deinit(ctx.allocator);
    return result.toLegacy();
}

pub fn verifyOutcome(ctx: P2pkhSpendContext) VerificationOutcome {
    return thread.verifyExecutableScriptsWithLegacyP2SHOutcome(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyDetailed(ctx: P2pkhSpendContext) VerificationResult {
    return thread.verifyExecutableScriptsWithLegacyP2SHDetailed(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyTraced(ctx: P2pkhSpendContext) TracedVerificationResult {
    return thread.verifyExecutableScriptsWithLegacyP2SHTraced(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyPrevout(ctx: PrevoutSpendContext) Error!bool {
    return thread.verifyExecutableScriptsWithLegacyP2SH(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.previous_output.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyPrevoutOutcome(ctx: PrevoutSpendContext) VerificationOutcome {
    return thread.verifyExecutableScriptsWithLegacyP2SHOutcome(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.previous_output.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyPrevoutDetailed(ctx: PrevoutSpendContext) VerificationResult {
    return thread.verifyExecutableScriptsWithLegacyP2SHDetailed(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.previous_output.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

pub fn verifyPrevoutTraced(ctx: PrevoutSpendContext) TracedVerificationResult {
    return thread.verifyExecutableScriptsWithLegacyP2SHTraced(
        ctx.executionContext(),
        ctx.unlocking_script,
        ctx.previous_output.locking_script,
        ctx.enable_legacy_p2sh,
    );
}

test "interpreter verifyDetailed exposes structured false results" {
    const allocator = std.testing.allocator;
    var tx = Transaction{
        .version = 2,
        .inputs = &[_]Input{
            .{
                .previous_outpoint = OutPoint{
                    .txid = .{ .bytes = @as([32]u8, @splat(0)) },
                    .index = 0,
                },
                .unlocking_script = Script.init(&[_]u8{}),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]Output{
            .{
                .satoshis = 1,
                .locking_script = Script.init(&[_]u8{
                    @intFromEnum(@import("opcode.zig").Opcode.OP_0),
                }),
            },
        },
        .lock_time = 0,
    };

    var result = verifyDetailed(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_satoshis = 1,
        .unlocking_script = Script.init(&[_]u8{}),
        .locking_script = tx.outputs[0].locking_script,
    });
    defer result.deinit(allocator);

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(VerificationTerminal.false_result, result.terminal);
    try std.testing.expectEqual(ScriptPhase.final, result.phase);
}

test "interpreter verifyOutcome exposes compact false results" {
    const allocator = std.testing.allocator;
    var tx = Transaction{
        .version = 2,
        .inputs = &[_]Input{
            .{
                .previous_outpoint = OutPoint{
                    .txid = .{ .bytes = @as([32]u8, @splat(0)) },
                    .index = 0,
                },
                .unlocking_script = Script.init(&[_]u8{}),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]Output{
            .{
                .satoshis = 1,
                .locking_script = Script.init(&[_]u8{
                    @intFromEnum(@import("opcode.zig").Opcode.OP_0),
                }),
            },
        },
        .lock_time = 0,
    };

    try std.testing.expectEqualDeep(VerificationOutcome.false_result, verifyOutcome(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_satoshis = 1,
        .unlocking_script = Script.init(&[_]u8{}),
        .locking_script = tx.outputs[0].locking_script,
    }));
}

test "interpreter verifyPrevoutDetailed exposes structured false results" {
    const allocator = std.testing.allocator;
    var tx = Transaction{
        .version = 2,
        .inputs = &[_]Input{
            .{
                .previous_outpoint = OutPoint{
                    .txid = .{ .bytes = @as([32]u8, @splat(0)) },
                    .index = 0,
                },
                .unlocking_script = Script.init(&[_]u8{}),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]Output{
            .{
                .satoshis = 1,
                .locking_script = Script.init(&[_]u8{
                    @intFromEnum(@import("opcode.zig").Opcode.OP_0),
                }),
            },
        },
        .lock_time = 0,
    };

    var result = verifyPrevoutDetailed(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_output = tx.outputs[0],
        .unlocking_script = tx.inputs[0].unlocking_script,
    });
    defer result.deinit(allocator);

    try std.testing.expect(!result.success);
    try std.testing.expectEqual(VerificationTerminal.false_result, result.terminal);
    try std.testing.expectEqual(ScriptPhase.final, result.phase);
}

test "interpreter verifyPrevoutOutcome exposes compact false results" {
    const allocator = std.testing.allocator;
    var tx = Transaction{
        .version = 2,
        .inputs = &[_]Input{
            .{
                .previous_outpoint = OutPoint{
                    .txid = .{ .bytes = @as([32]u8, @splat(0)) },
                    .index = 0,
                },
                .unlocking_script = Script.init(&[_]u8{}),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]Output{
            .{
                .satoshis = 1,
                .locking_script = Script.init(&[_]u8{
                    @intFromEnum(@import("opcode.zig").Opcode.OP_0),
                }),
            },
        },
        .lock_time = 0,
    };

    try std.testing.expectEqualDeep(VerificationOutcome.false_result, verifyPrevoutOutcome(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_output = tx.outputs[0],
        .unlocking_script = Script.init(&[_]u8{}),
    }));
}

test "interpreter verifyPrevout can explicitly execute legacy P2SH redeem scripts" {
    const allocator = std.testing.allocator;
    const hash = @import("../crypto/hash.zig");
    const Opcode = @import("opcode.zig").Opcode;

    const redeem_script_bytes = [_]u8{@intFromEnum(Opcode.OP_0)};
    const redeem_hash = hash.hash160(&redeem_script_bytes);
    const p2sh_locking_script = [_]u8{
        @intFromEnum(Opcode.OP_HASH160),
        0x14,
    } ++ redeem_hash.bytes ++ [_]u8{@intFromEnum(Opcode.OP_EQUAL)};
    const unlocking_script_bytes = [_]u8{ 0x01, 0x00 };

    var tx = Transaction{
        .version = 2,
        .inputs = &[_]Input{
            .{
                .previous_outpoint = OutPoint{
                    .txid = .{ .bytes = @as([32]u8, @splat(0x11)) },
                    .index = 0,
                },
                .unlocking_script = Script.init(&unlocking_script_bytes),
                .sequence = 0xffff_ffff,
            },
        },
        .outputs = &[_]Output{
            .{
                .satoshis = 1,
                .locking_script = Script.init(&[_]u8{@intFromEnum(Opcode.OP_1)}),
            },
        },
        .lock_time = 0,
    };

    const prevout = Output{
        .satoshis = 1,
        .locking_script = Script.init(&p2sh_locking_script),
    };

    try std.testing.expect(try verifyPrevout(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_output = prevout,
        .unlocking_script = Script.init(&unlocking_script_bytes),
    }));

    try std.testing.expect(!(try verifyPrevout(.{
        .allocator = allocator,
        .tx = &tx,
        .input_index = 0,
        .previous_output = prevout,
        .unlocking_script = Script.init(&unlocking_script_bytes),
        .enable_legacy_p2sh = true,
    })));
}
