//! Platform shim for std facilities removed in Zig 0.16.

const std = @import("std");
const builtin = @import("builtin");

/// Fill `buf` with cryptographically secure random bytes from the OS.
///
/// Uses the `randomSecure` implementation of `std.Io.Threaded` (getrandom on
/// Linux with EINTR retry and errno checking, `random_get` on WASI without
/// libc, the CNG device on Windows, arc4random_buf where libc provides it).
/// Only the entropy path of the global single-threaded instance is used; it
/// needs no initialization and spawns nothing. Panics if the OS cannot
/// supply entropy: there is no safe fallback for key material.
pub fn randomBytes(buf: []u8) void {
    const io = std.Io.Threaded.global_single_threaded.io();
    io.randomSecure(buf) catch |err| std.debug.panic("bsvz: OS entropy unavailable: {s}", .{@errorName(err)});
}

test "randomBytes fills the buffer" {
    var a: [64]u8 = @splat(0);
    var b: [64]u8 = @splat(0);
    randomBytes(&a);
    randomBytes(&b);
    try std.testing.expect(!std.mem.eql(u8, &a, &b));
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
