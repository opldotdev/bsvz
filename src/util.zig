//! Platform shim for std facilities removed in Zig 0.16.

const std = @import("std");
const builtin = @import("builtin");

/// Fill `buf` with cryptographically secure random bytes.
pub fn randomBytes(buf: []u8) void {
    if (builtin.os.tag == .linux) {
        var filled: usize = 0;
        while (filled < buf.len) {
            filled += std.os.linux.getrandom(buf[filled..].ptr, buf.len - filled, 0);
        }
    } else {
        arc4random_buf(buf.ptr, buf.len);
    }
}

extern "c" fn arc4random_buf(buf: [*]u8, nbytes: usize) void;

/// Milliseconds since the Unix epoch.
pub fn nowMilli() i64 {
    var ts: std.c.timespec = undefined;
    if (builtin.os.tag == .linux) {
        _ = std.os.linux.clock_gettime(.REALTIME, &ts);
    } else {
        _ = std.c.clock_gettime(.REALTIME, &ts);
    }
    return @as(i64, ts.sec) * 1000 + @divTrunc(@as(i64, ts.nsec), 1_000_000);
}

/// Seconds since the Unix epoch.
pub fn nowSecs() u64 {
    var ts: std.c.timespec = undefined;
    if (builtin.os.tag == .linux) {
        _ = std.os.linux.clock_gettime(.REALTIME, &ts);
    } else {
        _ = std.c.clock_gettime(.REALTIME, &ts);
    }
    return @intCast(ts.sec);
}

test "nowSecs is plausible" {
    try std.testing.expect(nowSecs() > 1_700_000_000);
}

/// Replacement for `std.testing.refAllDeclsRecursive`, removed in Zig 0.16.
/// Compatible with 0.16 (Declaration structs) and 0.17+ (plain name strings).
pub fn refAllDeclsRecursive(comptime T: type) void {
    if (!builtin.is_test) return;
    inline for (comptime std.meta.declarations(T)) |decl| {
        const D = if (comptime @typeInfo(@TypeOf(decl)) == .pointer)
            @field(T, decl)
        else
            @field(T, decl.name);
        if (comptime @TypeOf(D) == type) {
            switch (@typeInfo(D)) {
                .@"struct", .@"enum", .@"union", .@"opaque" => refAllDeclsRecursive(D),
                else => {},
            }
        }
        _ = &D;
    }
}
