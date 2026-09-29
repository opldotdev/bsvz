//! Chronicle opcode vectors checked against go-sdk.
//!
//! Every row below is a locking script run once through go-sdk's interpreter
//! (script/interpreter at go-sdk aaa650f, WithTx + WithForkID +
//! WithAfterGenesis, plus WithAfterChronicle when `.chronicle`) and once
//! through bsvz (`ExecutionFlags.postChronicleBsv()` / `postGenesisBsv()`).
//! The expected outcome and final stack are go-sdk's, copied verbatim; the
//! go-sdk error is mapped to the bsvz error for the same failure. The rows
//! and the oracle live in tests/support/chronicle_oracle (regenerate with
//! `python3 cases.py > cases.txt && go run . < cases.txt > oracle.txt &&
//! python3 genzig.py`).
//!
//! What they pin, per go-sdk operations.go:
//! - OP_2MUL / OP_2DIV (opcode2Mul / opcode2Div): exact bignum x2 and /2,
//!   /2 truncating toward zero (-1 -> 0, -5 -> -2), minimally encoded, well
//!   past 64 bits.
//! - OP_LSHIFTNUM / OP_RSHIFTNUM (opcodeShiftNum): numeric shifts.
//!   go-sdk's right shift rounds toward negative infinity (-5 >> 1 == -3,
//!   -1 >> 200 == -1), but that disagrees with SV Node, the consensus
//!   reference: SV Node's bignum path (`bsv::bint::operator>>=` in
//!   big_int.cpp, OpenSSL `BN_rshift` on a sign-magnitude BIGNUM) rounds
//!   toward zero instead (-5 >> 1 == -2, -1 >> 200 == 0). The rsh_1, rsh_2,
//!   rsh_3, rsh_7, rsh_9 and rsh_11 rows below have been corrected by hand
//!   to follow SV Node rather than the go-sdk oracle output that
//!   chronicle_oracle produced; every other row here is unaffected because
//!   it is either non-negative or divides its shift count evenly. go-sdk's
//!   right shift is being fixed upstream: bsv-blockchain/go-sdk PR #370
//!   (fix/rshiftnum-round-toward-zero). Left shift is exact and
//!   sign-preserving either way (-1 << 7 == -128) and both SDKs agree on
//!   it, but SV Node additionally rejects a shift whose result (or even a
//!   pre-shift size estimate) would exceed MaxScriptNumLength
//!   (script_num.cpp `CScriptNum::operator<<=`); the lsh_overflow_* rows
//!   below are not go-sdk-derived and were added by hand for that.
//! - OP_SUBSTR / OP_LEFT / OP_RIGHT range checks, OP_VER, OP_VERIF /
//!   OP_VERNOTIF (exact 4-byte LE version match).
//! - The same bytes before Chronicle: 2MUL/2DIV and VER/VERIF fail, the
//!   0xb3..0xb7 NOPs do nothing.
const std = @import("std");
const bsvz = @import("bsvz");

const engine = bsvz.script.engine;
const Script = bsvz.script.Script;
const Transaction = bsvz.transaction.Transaction;
const ExecutionFlags = bsvz.script.context.ExecutionFlags;

const Outcome = union(enum) {
    success,
    false_result,
    script_error: anyerror,
};

const Row = struct {
    name: []const u8,
    chronicle: bool,
    version: u32,
    script: []const u8,
    outcome: Outcome,
    stack: []const []const u8,
};

const rows = [_]Row{
    .{ .name = "2mul_0", .chronicle = true, .version = 0x00000001, .script = "008d", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "2div_0", .chronicle = true, .version = 0x00000001, .script = "008e", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "2mul_1", .chronicle = true, .version = 0x00000001, .script = "01018d", .outcome = .success, .stack = &.{"02"} },
    .{ .name = "2div_1", .chronicle = true, .version = 0x00000001, .script = "01018e", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "2mul_2", .chronicle = true, .version = 0x00000001, .script = "01818d", .outcome = .success, .stack = &.{"82"} },
    .{ .name = "2div_2", .chronicle = true, .version = 0x00000001, .script = "01818e", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "2mul_3", .chronicle = true, .version = 0x00000001, .script = "01028d", .outcome = .success, .stack = &.{"04"} },
    .{ .name = "2div_3", .chronicle = true, .version = 0x00000001, .script = "01028e", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "2mul_4", .chronicle = true, .version = 0x00000001, .script = "01828d", .outcome = .success, .stack = &.{"84"} },
    .{ .name = "2div_4", .chronicle = true, .version = 0x00000001, .script = "01828e", .outcome = .success, .stack = &.{"81"} },
    .{ .name = "2mul_5", .chronicle = true, .version = 0x00000001, .script = "01038d", .outcome = .success, .stack = &.{"06"} },
    .{ .name = "2div_5", .chronicle = true, .version = 0x00000001, .script = "01038e", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "2mul_6", .chronicle = true, .version = 0x00000001, .script = "01838d", .outcome = .success, .stack = &.{"86"} },
    .{ .name = "2div_6", .chronicle = true, .version = 0x00000001, .script = "01838e", .outcome = .success, .stack = &.{"81"} },
    .{ .name = "2mul_7", .chronicle = true, .version = 0x00000001, .script = "01058d", .outcome = .success, .stack = &.{"0a"} },
    .{ .name = "2div_7", .chronicle = true, .version = 0x00000001, .script = "01058e", .outcome = .success, .stack = &.{"02"} },
    .{ .name = "2mul_8", .chronicle = true, .version = 0x00000001, .script = "01858d", .outcome = .success, .stack = &.{"8a"} },
    .{ .name = "2div_8", .chronicle = true, .version = 0x00000001, .script = "01858e", .outcome = .success, .stack = &.{"82"} },
    .{ .name = "2mul_9", .chronicle = true, .version = 0x00000001, .script = "013f8d", .outcome = .success, .stack = &.{"7e"} },
    .{ .name = "2div_9", .chronicle = true, .version = 0x00000001, .script = "013f8e", .outcome = .success, .stack = &.{"1f"} },
    .{ .name = "2mul_10", .chronicle = true, .version = 0x00000001, .script = "01408d", .outcome = .success, .stack = &.{"8000"} },
    .{ .name = "2div_10", .chronicle = true, .version = 0x00000001, .script = "01408e", .outcome = .success, .stack = &.{"20"} },
    .{ .name = "2mul_11", .chronicle = true, .version = 0x00000001, .script = "01c08d", .outcome = .success, .stack = &.{"8080"} },
    .{ .name = "2div_11", .chronicle = true, .version = 0x00000001, .script = "01c08e", .outcome = .success, .stack = &.{"a0"} },
    .{ .name = "2mul_12", .chronicle = true, .version = 0x00000001, .script = "017f8d", .outcome = .success, .stack = &.{"fe00"} },
    .{ .name = "2div_12", .chronicle = true, .version = 0x00000001, .script = "017f8e", .outcome = .success, .stack = &.{"3f"} },
    .{ .name = "2mul_13", .chronicle = true, .version = 0x00000001, .script = "0280008d", .outcome = .success, .stack = &.{"0001"} },
    .{ .name = "2div_13", .chronicle = true, .version = 0x00000001, .script = "0280008e", .outcome = .success, .stack = &.{"40"} },
    .{ .name = "2mul_14", .chronicle = true, .version = 0x00000001, .script = "0280808d", .outcome = .success, .stack = &.{"0081"} },
    .{ .name = "2div_14", .chronicle = true, .version = 0x00000001, .script = "0280808e", .outcome = .success, .stack = &.{"c0"} },
    .{ .name = "2mul_15", .chronicle = true, .version = 0x00000001, .script = "02ff008d", .outcome = .success, .stack = &.{"fe01"} },
    .{ .name = "2div_15", .chronicle = true, .version = 0x00000001, .script = "02ff008e", .outcome = .success, .stack = &.{"7f"} },
    .{ .name = "2mul_16", .chronicle = true, .version = 0x00000001, .script = "02ff7f8d", .outcome = .success, .stack = &.{"feff00"} },
    .{ .name = "2div_16", .chronicle = true, .version = 0x00000001, .script = "02ff7f8e", .outcome = .success, .stack = &.{"ff3f"} },
    .{ .name = "2mul_17", .chronicle = true, .version = 0x00000001, .script = "04ffffff7f8d", .outcome = .success, .stack = &.{"feffffff00"} },
    .{ .name = "2div_17", .chronicle = true, .version = 0x00000001, .script = "04ffffff7f8e", .outcome = .success, .stack = &.{"ffffff3f"} },
    .{ .name = "2mul_18", .chronicle = true, .version = 0x00000001, .script = "0500000080008d", .outcome = .success, .stack = &.{"0000000001"} },
    .{ .name = "2div_18", .chronicle = true, .version = 0x00000001, .script = "0500000080008e", .outcome = .success, .stack = &.{"00000040"} },
    .{ .name = "2mul_19", .chronicle = true, .version = 0x00000001, .script = "0500000080808d", .outcome = .success, .stack = &.{"0000000081"} },
    .{ .name = "2div_19", .chronicle = true, .version = 0x00000001, .script = "0500000080808e", .outcome = .success, .stack = &.{"000000c0"} },
    .{ .name = "2mul_20", .chronicle = true, .version = 0x00000001, .script = "0800000000000000408d", .outcome = .success, .stack = &.{"000000000000008000"} },
    .{ .name = "2div_20", .chronicle = true, .version = 0x00000001, .script = "0800000000000000408e", .outcome = .success, .stack = &.{"0000000000000020"} },
    .{ .name = "2mul_21", .chronicle = true, .version = 0x00000001, .script = "08ffffffffffffff7f8d", .outcome = .success, .stack = &.{"feffffffffffffff00"} },
    .{ .name = "2div_21", .chronicle = true, .version = 0x00000001, .script = "08ffffffffffffff7f8e", .outcome = .success, .stack = &.{"ffffffffffffff3f"} },
    .{ .name = "2mul_22", .chronicle = true, .version = 0x00000001, .script = "08ffffffffffffffff8d", .outcome = .success, .stack = &.{"feffffffffffffff80"} },
    .{ .name = "2div_22", .chronicle = true, .version = 0x00000001, .script = "08ffffffffffffffff8e", .outcome = .success, .stack = &.{"ffffffffffffffbf"} },
    .{ .name = "2mul_23", .chronicle = true, .version = 0x00000001, .script = "090000000000000080008d", .outcome = .success, .stack = &.{"000000000000000001"} },
    .{ .name = "2div_23", .chronicle = true, .version = 0x00000001, .script = "090000000000000080008e", .outcome = .success, .stack = &.{"0000000000000040"} },
    .{ .name = "2mul_24", .chronicle = true, .version = 0x00000001, .script = "090000000000000080808d", .outcome = .success, .stack = &.{"000000000000000081"} },
    .{ .name = "2div_24", .chronicle = true, .version = 0x00000001, .script = "090000000000000080808e", .outcome = .success, .stack = &.{"00000000000000c0"} },
    .{ .name = "2mul_25", .chronicle = true, .version = 0x00000001, .script = "090100000000000080008d", .outcome = .success, .stack = &.{"020000000000000001"} },
    .{ .name = "2div_25", .chronicle = true, .version = 0x00000001, .script = "090100000000000080008e", .outcome = .success, .stack = &.{"0000000000000040"} },
    .{ .name = "2mul_26", .chronicle = true, .version = 0x00000001, .script = "090100000000000000018d", .outcome = .success, .stack = &.{"020000000000000002"} },
    .{ .name = "2div_26", .chronicle = true, .version = 0x00000001, .script = "090100000000000000018e", .outcome = .success, .stack = &.{"000000000000008000"} },
    .{ .name = "2mul_27", .chronicle = true, .version = 0x00000001, .script = "090100000000000000818d", .outcome = .success, .stack = &.{"020000000000000082"} },
    .{ .name = "2div_27", .chronicle = true, .version = 0x00000001, .script = "090100000000000000818e", .outcome = .success, .stack = &.{"000000000000008080"} },
    .{ .name = "2mul_28", .chronicle = true, .version = 0x00000001, .script = "1100000000000000000000000000000080008d", .outcome = .success, .stack = &.{"0000000000000000000000000000000001"} },
    .{ .name = "2div_28", .chronicle = true, .version = 0x00000001, .script = "1100000000000000000000000000000080008e", .outcome = .success, .stack = &.{"00000000000000000000000000000040"} },
    .{ .name = "2mul_29", .chronicle = true, .version = 0x00000001, .script = "1a01000000000000000000000000000000000000000000000000018d", .outcome = .success, .stack = &.{"0200000000000000000000000000000000000000000000000002"} },
    .{ .name = "2div_29", .chronicle = true, .version = 0x00000001, .script = "1a01000000000000000000000000000000000000000000000000018e", .outcome = .success, .stack = &.{"0000000000000000000000000000000000000000000000008000"} },
    .{ .name = "2mul_30", .chronicle = true, .version = 0x00000001, .script = "1a01000000000000000000000000000000000000000000000000818d", .outcome = .success, .stack = &.{"0200000000000000000000000000000000000000000000000082"} },
    .{ .name = "2div_30", .chronicle = true, .version = 0x00000001, .script = "1a01000000000000000000000000000000000000000000000000818e", .outcome = .success, .stack = &.{"0000000000000000000000000000000000000000000000008080"} },
    .{ .name = "2mul_31", .chronicle = true, .version = 0x00000001, .script = "20edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f8d", .outcome = .success, .stack = &.{"daffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00"} },
    .{ .name = "2div_31", .chronicle = true, .version = 0x00000001, .script = "20edffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f8e", .outcome = .success, .stack = &.{"f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f"} },
    .{ .name = "lsh_0", .chronicle = true, .version = 0x00000001, .script = "01010108b6", .outcome = .success, .stack = &.{"0001"} },
    .{ .name = "lsh_1", .chronicle = true, .version = 0x00000001, .script = "01810101b6", .outcome = .success, .stack = &.{"82"} },
    .{ .name = "lsh_2", .chronicle = true, .version = 0x00000001, .script = "010500b6", .outcome = .success, .stack = &.{"05"} },
    .{ .name = "lsh_3", .chronicle = true, .version = 0x00000001, .script = "00022c01b6", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "lsh_4", .chronicle = true, .version = 0x00000001, .script = "01010140b6", .outcome = .success, .stack = &.{"000000000000000001"} },
    .{ .name = "lsh_5", .chronicle = true, .version = 0x00000001, .script = "01830164b6", .outcome = .success, .stack = &.{"000000000000000000000000b0"} },
    .{ .name = "lsh_6", .chronicle = true, .version = 0x00000001, .script = "090000000000000000010101b6", .outcome = .success, .stack = &.{"000000000000000002"} },
    .{ .name = "lsh_7", .chronicle = true, .version = 0x00000001, .script = "0239300111b6", .outcome = .success, .stack = &.{"00007260"} },
    .{ .name = "rsh_0", .chronicle = true, .version = 0x00000001, .script = "01100102b7", .outcome = .success, .stack = &.{"04"} },
    // rsh_1: -5 >> 1. go-sdk (floor) gives -3 (0x83); SV Node (toward zero) gives -2 (0x82).
    .{ .name = "rsh_1", .chronicle = true, .version = 0x00000001, .script = "01850101b7", .outcome = .success, .stack = &.{"82"} },
    // rsh_2: -1 >> 1. go-sdk (floor) gives -1 (0x81); SV Node (toward zero) gives 0.
    .{ .name = "rsh_2", .chronicle = true, .version = 0x00000001, .script = "01810101b7", .outcome = .false_result, .stack = &.{""} },
    // rsh_3: -1 >> 200. go-sdk's negative-shift-converges-to-(-1) rule gives -1 (0x81);
    // SV Node shifts the magnitude (1 >> 200 == 0) and keeps the sign, giving 0.
    .{ .name = "rsh_3", .chronicle = true, .version = 0x00000001, .script = "018102c800b7", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "rsh_4", .chronicle = true, .version = 0x00000001, .script = "010500b7", .outcome = .success, .stack = &.{"05"} },
    .{ .name = "rsh_5", .chronicle = true, .version = 0x00000001, .script = "01010101b7", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "rsh_6", .chronicle = true, .version = 0x00000001, .script = "01900102b7", .outcome = .success, .stack = &.{"84"} },
    // rsh_7: -17 >> 2. go-sdk (floor) gives -5 (0x85); SV Node (toward zero) gives -4 (0x84).
    .{ .name = "rsh_7", .chronicle = true, .version = 0x00000001, .script = "01910102b7", .outcome = .success, .stack = &.{"84"} },
    .{ .name = "rsh_8", .chronicle = true, .version = 0x00000001, .script = "0d050000000000000000000000100163b7", .outcome = .success, .stack = &.{"02"} },
    // rsh_9: same magnitude as rsh_8 but negative, >> 99. go-sdk (floor) gives 0x83; SV Node (toward zero) gives 0x82.
    .{ .name = "rsh_9", .chronicle = true, .version = 0x00000001, .script = "0d050000000000000000000000900163b7", .outcome = .success, .stack = &.{"82"} },
    .{ .name = "rsh_10", .chronicle = true, .version = 0x00000001, .script = "0107022c01b7", .outcome = .false_result, .stack = &.{""} },
    // rsh_11: -7 >> 300. go-sdk's negative-shift-converges-to-(-1) rule gives -1 (0x81);
    // SV Node shifts the magnitude (7 >> 300 == 0) and keeps the sign, giving 0.
    .{ .name = "rsh_11", .chronicle = true, .version = 0x00000001, .script = "0187022c01b7", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "lsh_neg", .chronicle = true, .version = 0x00000001, .script = "01010181b6", .outcome = .{ .script_error = error.NegativeShift }, .stack = &.{} },
    .{ .name = "rsh_neg", .chronicle = true, .version = 0x00000001, .script = "01010181b7", .outcome = .{ .script_error = error.NegativeShift }, .stack = &.{} },
    // Not go-sdk-derived (chronicle_oracle doesn't exercise these); added by
    // hand against SV Node's bint shift path.
    //
    // lsh_overflow_bytes: 0 << (32 MiB * 8 + 8). CScriptNum::operator<<='s
    // bint branch (script_num.cpp) rejects a shift once its
    // shift-count-in-bytes estimate alone exceeds MaxScriptNumLength, even
    // for a zero value that would otherwise still encode as zero bytes.
    .{ .name = "lsh_overflow_bytes", .chronicle = true, .version = 0x00000001, .script = "000408000010b6", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    // lsh_intmax_overflow / rsh_intmax_overflow: shift count 2147483648 ==
    // INT_MAX + 1. bsv::bint::operator<<=/operator>>=(const bint&) both
    // reject a shift count greater than INT_MAX outright (big_int.cpp) --
    // it does not saturate the way an out-of-range OP_LSHIFT/OP_RSHIFT byte
    // count would.
    .{ .name = "lsh_intmax_overflow", .chronicle = true, .version = 0x00000001, .script = "0101050000008000b6", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "rsh_intmax_overflow", .chronicle = true, .version = 0x00000001, .script = "0101050000008000b7", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_0", .chronicle = true, .version = 0x00000001, .script = "06616263646566000106b3", .outcome = .success, .stack = &.{"616263646566"} },
    .{ .name = "substr_1", .chronicle = true, .version = 0x00000001, .script = "0661626364656601010103b3", .outcome = .success, .stack = &.{"626364"} },
    .{ .name = "substr_2", .chronicle = true, .version = 0x00000001, .script = "0661626364656601050101b3", .outcome = .success, .stack = &.{"66"} },
    .{ .name = "substr_3", .chronicle = true, .version = 0x00000001, .script = "066162636465660000b3", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "substr_4", .chronicle = true, .version = 0x00000001, .script = "06616263646566010600b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_5", .chronicle = true, .version = 0x00000001, .script = "0661626364656601020105b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_6", .chronicle = true, .version = 0x00000001, .script = "0661626364656601810101b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_7", .chronicle = true, .version = 0x00000001, .script = "0661626364656601010181b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_8", .chronicle = true, .version = 0x00000001, .script = "06616263646566010700b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "substr_empty", .chronicle = true, .version = 0x00000001, .script = "000000b3", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "left_0", .chronicle = true, .version = 0x00000001, .script = "0661626364656600b4", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "right_0", .chronicle = true, .version = 0x00000001, .script = "0661626364656600b5", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "left_1", .chronicle = true, .version = 0x00000001, .script = "066162636465660102b4", .outcome = .success, .stack = &.{"6162"} },
    .{ .name = "right_1", .chronicle = true, .version = 0x00000001, .script = "066162636465660102b5", .outcome = .success, .stack = &.{"6566"} },
    .{ .name = "left_2", .chronicle = true, .version = 0x00000001, .script = "066162636465660106b4", .outcome = .success, .stack = &.{"616263646566"} },
    .{ .name = "right_2", .chronicle = true, .version = 0x00000001, .script = "066162636465660106b5", .outcome = .success, .stack = &.{"616263646566"} },
    .{ .name = "left_3", .chronicle = true, .version = 0x00000001, .script = "066162636465660107b4", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "right_3", .chronicle = true, .version = 0x00000001, .script = "066162636465660107b5", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "left_4", .chronicle = true, .version = 0x00000001, .script = "066162636465660181b4", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "right_4", .chronicle = true, .version = 0x00000001, .script = "066162636465660181b5", .outcome = .{ .script_error = error.NumberTooBig }, .stack = &.{} },
    .{ .name = "ver_v1", .chronicle = true, .version = 0x00000001, .script = "62", .outcome = .success, .stack = &.{"01000000"} },
    .{ .name = "ver_v2", .chronicle = true, .version = 0x00000002, .script = "62", .outcome = .success, .stack = &.{"02000000"} },
    .{ .name = "ver_big", .chronicle = true, .version = 0xfffffffe, .script = "62", .outcome = .success, .stack = &.{"feffffff"} },
    .{ .name = "verif_match", .chronicle = true, .version = 0x00000002, .script = "04020000006551670068", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "verif_short", .chronicle = true, .version = 0x00000002, .script = "01026551670068", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "verif_other", .chronicle = true, .version = 0x00000002, .script = "04010000006551670068", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "vernotif_match", .chronicle = true, .version = 0x00000002, .script = "04020000006651670068", .outcome = .false_result, .stack = &.{""} },
    .{ .name = "vernotif_other", .chronicle = true, .version = 0x00000002, .script = "04010000006651670068", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "verif_empty", .chronicle = true, .version = 0x00000002, .script = "656851", .outcome = .{ .script_error = error.UnbalancedConditionals }, .stack = &.{} },
    .{ .name = "verif_untaken", .chronicle = true, .version = 0x00000002, .script = "006365686851", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "verif_untaken_unbalanced", .chronicle = true, .version = 0x00000002, .script = "0063656851", .outcome = .{ .script_error = error.UnbalancedConditionals }, .stack = &.{} },
    .{ .name = "pre_2mul", .chronicle = false, .version = 0x00000001, .script = "01018d", .outcome = .{ .script_error = error.UnknownOpcode }, .stack = &.{} },
    .{ .name = "pre_2div", .chronicle = false, .version = 0x00000001, .script = "01028e", .outcome = .{ .script_error = error.UnknownOpcode }, .stack = &.{} },
    .{ .name = "pre_2mul_untaken", .chronicle = false, .version = 0x00000001, .script = "00638d6851", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "pre_ver", .chronicle = false, .version = 0x00000002, .script = "62", .outcome = .{ .script_error = error.UnknownOpcode }, .stack = &.{} },
    .{ .name = "pre_verif", .chronicle = false, .version = 0x00000002, .script = "0402000000655168", .outcome = .{ .script_error = error.UnknownOpcode }, .stack = &.{} },
    .{ .name = "pre_verif_untaken", .chronicle = false, .version = 0x00000002, .script = "0063656851", .outcome = .success, .stack = &.{"01"} },
    .{ .name = "pre_substr", .chronicle = false, .version = 0x00000001, .script = "0661626364656601010103b3", .outcome = .success, .stack = &.{ "616263646566", "01", "03" } },
    .{ .name = "pre_rsh", .chronicle = false, .version = 0x00000001, .script = "01100102b7", .outcome = .success, .stack = &.{ "10", "02" } },
    .{ .name = "pre_lsh", .chronicle = false, .version = 0x00000001, .script = "01010108b6", .outcome = .success, .stack = &.{ "01", "08" } },
    .{ .name = "pre_left", .chronicle = false, .version = 0x00000001, .script = "066162636465660102b4", .outcome = .success, .stack = &.{ "616263646566", "02" } },
    .{ .name = "pre_right", .chronicle = false, .version = 0x00000001, .script = "066162636465660102b5", .outcome = .success, .stack = &.{ "616263646566", "02" } },
};

fn runRow(allocator: std.mem.Allocator, row: Row) !void {
    const script_bytes = try allocator.alloc(u8, row.script.len / 2);
    defer allocator.free(script_bytes);
    _ = try std.fmt.hexToBytes(script_bytes, row.script);

    const tx = Transaction{
        .version = @bitCast(row.version),
        .inputs = &.{},
        .outputs = &.{},
        .lock_time = 0,
    };
    const flags = if (row.chronicle) ExecutionFlags.postChronicleBsv() else ExecutionFlags.postGenesisBsv();

    const result = engine.executeScript(.{ .allocator = allocator, .tx = &tx, .flags = flags }, Script.init(script_bytes));
    switch (row.outcome) {
        .script_error => |want| {
            if (result) |value| {
                var owned = value;
                owned.deinit(allocator);
                return error.ExpectedScriptError;
            } else |got| {
                try std.testing.expectEqual(want, @as(anyerror, got));
            }
        },
        .success, .false_result => {
            var value = try result;
            defer value.deinit(allocator);
            try std.testing.expectEqual(row.outcome == .success, value.success);
            try std.testing.expectEqual(row.stack.len, value.state.stack.items.len);
            for (row.stack, value.state.stack.items) |want_hex, got| {
                const want = try allocator.alloc(u8, want_hex.len / 2);
                defer allocator.free(want);
                _ = try std.fmt.hexToBytes(want, want_hex);
                try std.testing.expectEqualSlices(u8, want, got);
            }
        },
    }
}

test "chronicle opcodes match go-sdk row for row" {
    const allocator = std.testing.allocator;
    for (rows) |row| {
        runRow(allocator, row) catch |err| {
            std.debug.print("chronicle row {s} failed: {}\n", .{ row.name, err });
            return err;
        };
    }
}

fn execute(allocator: std.mem.Allocator, tx: ?*const Transaction, flags: ExecutionFlags, script_bytes: []const u8) !engine.ExecutionResult {
    return engine.executeScript(.{ .allocator = allocator, .tx = tx, .flags = flags }, Script.init(script_bytes));
}

test "chronicle requires genesis" {
    // go-sdk thread.go: "UTXOAfterChronicle requires UTXOAfterGenesis".
    try std.testing.expectError(error.InvalidFlags, execute(std.testing.allocator, null, .{
        .utxo_after_genesis = false,
        .utxo_after_chronicle = true,
    }, &[_]u8{0x51}));
}

test "chronicle arithmetic honours minimal_data on its operands" {
    const allocator = std.testing.allocator;
    // 0x0100 is 1, non-minimally encoded.
    const script = [_]u8{ 0x02, 0x01, 0x00, 0x8d };

    var flags = ExecutionFlags.postChronicleBsv();
    var lax = try execute(allocator, null, flags, &script);
    defer lax.deinit(allocator);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x02}, lax.state.stack.items[0]);

    flags.minimal_data = true;
    try std.testing.expectError(error.MinimalData, execute(allocator, null, flags, &script));
}

test "OP_VER needs a transaction" {
    try std.testing.expectError(error.MissingChecksigContext, execute(std.testing.allocator, null, ExecutionFlags.postChronicleBsv(), &[_]u8{0x62}));
}

test "0xb3..0xb7 are upgradable NOPs only before chronicle" {
    const allocator = std.testing.allocator;
    // "abcdef" 1 3 OP_SUBSTR
    const script = [_]u8{ 0x06, 'a', 'b', 'c', 'd', 'e', 'f', 0x51, 0x53, 0xb3 };

    var pre = ExecutionFlags.postGenesisBsv();
    pre.discourage_upgradable_nops = true;
    try std.testing.expectError(error.DiscourageUpgradableNops, execute(allocator, null, pre, &script));

    var post = ExecutionFlags.postChronicleBsv();
    post.discourage_upgradable_nops = true;
    var result = try execute(allocator, null, post, &script);
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 1), result.state.stack.items.len);
    try std.testing.expectEqualSlices(u8, "bcd", result.state.stack.items[0]);
}

fn numberOpScript(allocator: std.mem.Allocator, number_len: usize, op: u8) ![]u8 {
    // PUSHDATA4 <number_len bytes: 0x00 .. 0x00 0x01> op: 2^(8 * (number_len - 1)),
    // minimally encoded.
    const out = try allocator.alloc(u8, 5 + number_len + 1);
    out[0] = 0x4e;
    std.mem.writeInt(u32, out[1..5], @intCast(number_len), .little);
    @memset(out[5 .. 5 + number_len], 0);
    out[5 + number_len - 1] = 0x01;
    out[out.len - 1] = op;
    return out;
}

test "chronicle raises the script number length limit to 32 MiB" {
    const allocator = std.testing.allocator;
    const limits = bsvz.script.limits;
    try std.testing.expectEqual(@as(usize, 32 * 1024 * 1024), limits.max_script_number_length_after_chronicle);

    // 750,001 bytes: over the post-Genesis limit (go-sdk afterGenesisConfig:
    // 750 * 1000), under Chronicle's (afterChronicleConfig: 32 MiB).
    const over_genesis = try numberOpScript(allocator, 750_001, 0x8b); // OP_1ADD
    defer allocator.free(over_genesis);
    try std.testing.expectError(error.NumberTooBig, execute(allocator, null, ExecutionFlags.postGenesisBsv(), over_genesis));
    var ok = try execute(allocator, null, ExecutionFlags.postChronicleBsv(), over_genesis);
    defer ok.deinit(allocator);
    try std.testing.expect(ok.success);
    try std.testing.expectEqual(@as(usize, 750_001), ok.state.stack.items[0].len);
    try std.testing.expectEqual(@as(u8, 0x01), ok.state.stack.items[0][0]);
    try std.testing.expectEqual(@as(u8, 0x01), ok.state.stack.items[0][750_000]);

    // Chronicle's limit replaces max_script_number_length (as go-sdk's config
    // does), so a caller's lower post-Genesis limit does not apply under it.
    var capped = ExecutionFlags.postChronicleBsv();
    capped.max_script_number_length = 4;
    var five = try execute(allocator, null, capped, &[_]u8{ 0x05, 0, 0, 0, 0, 1, 0x8b });
    defer five.deinit(allocator);
    try std.testing.expect(five.success);

    // One byte over 32 MiB fails under Chronicle too.
    const over_chronicle = try numberOpScript(allocator, limits.max_script_number_length_after_chronicle + 1, 0x8d); // OP_2MUL
    defer allocator.free(over_chronicle);
    try std.testing.expectError(error.NumberTooBig, execute(allocator, null, ExecutionFlags.postChronicleBsv(), over_chronicle));
}
