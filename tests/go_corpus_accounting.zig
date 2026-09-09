const std = @import("std");

var test_threaded: ?std.Io.Threaded = null;

fn testIo() std.Io {
    if (test_threaded == null) {
        test_threaded = std.Io.Threaded.init(std.testing.allocator, .{ .environ = .empty });
    }
    return test_threaded.?.io();
}

const corpus_path = "../go-sdk/script/interpreter/data/script_tests.json";

const coverage_flags = @import("external_coverage_notice.zig");

fn accessOrRequire(rel_path: []const u8) !void {
    std.Io.Dir.cwd().access(testIo(), rel_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            if (coverage_flags.envRequiresExternalCoverage(std.heap.page_allocator)) return err;
            std.debug.print("skipping: external corpus not present: {s}\n", .{rel_path});
            return error.SkipZigTest;
        },
        else => return err,
    };
}

const RowAccounting = struct {
    counts: std.AutoHashMap(usize, usize),
    duplicate_count: usize,
    first_duplicate_row: ?usize,

    fn deinit(self: *RowAccounting) void {
        self.counts.deinit();
    }
};

fn collectAccountedRowRefs(allocator: std.mem.Allocator) !RowAccounting {
    var counts = std.AutoHashMap(usize, usize).init(allocator);
    errdefer counts.deinit();

    const io = testIo();
    var dir = try std.Io.Dir.cwd().openDir(io, "tests", .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    while (try iter.next(io)) |dir_entry| {
        if (dir_entry.kind != .file) continue;
        if (!std.mem.startsWith(u8, dir_entry.name, "go_")) continue;
        if (!std.mem.endsWith(u8, dir_entry.name, "_vectors.zig")) continue;

        const source = try dir.readFileAlloc(io, dir_entry.name, allocator, .limited(512 * 1024));
        defer allocator.free(source);

        var cursor: usize = 0;
        while (std.mem.indexOfPos(u8, source, cursor, ".row")) |row_pos| {
            var eq_pos = row_pos + ".row".len;
            while (eq_pos < source.len and std.ascii.isWhitespace(source[eq_pos])) : (eq_pos += 1) {}
            if (eq_pos >= source.len or source[eq_pos] != '=') {
                cursor = row_pos + ".row".len;
                continue;
            }

            var digits_start = eq_pos + 1;
            while (digits_start < source.len and std.ascii.isWhitespace(source[digits_start])) : (digits_start += 1) {}

            var digits_end = digits_start;
            while (digits_end < source.len and std.ascii.isDigit(source[digits_end])) : (digits_end += 1) {}
            if (digits_end > digits_start) {
                const row = try std.fmt.parseInt(usize, source[digits_start..digits_end], 10);
                const count_entry = try counts.getOrPut(row);
                if (count_entry.found_existing) {
                    count_entry.value_ptr.* += 1;
                } else {
                    count_entry.value_ptr.* = 1;
                }
            }
            cursor = if (digits_end > row_pos + ".row".len) digits_end else row_pos + ".row".len;
        }
    }

    var duplicate_count: usize = 0;
    var first_duplicate_row: ?usize = null;
    var iter_counts = counts.iterator();
    while (iter_counts.next()) |entry| {
        if (entry.value_ptr.* > 1) {
            duplicate_count += 1;
            if (first_duplicate_row == null) first_duplicate_row = entry.key_ptr.*;
        }
    }

    return .{
        .counts = counts,
        .duplicate_count = duplicate_count,
        .first_duplicate_row = first_duplicate_row,
    };
}

test "all go corpus rows are explicitly accounted for" {
    const allocator = std.testing.allocator;
    try accessOrRequire(corpus_path);

    var accounting = try collectAccountedRowRefs(allocator);
    defer accounting.deinit();

    const file = try std.Io.Dir.cwd().readFileAlloc(testIo(), corpus_path, allocator, .limited(8 * 1024 * 1024));
    defer allocator.free(file);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, file, .{});
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidEncoding;

    var uncovered_count: usize = 0;
    var first_missing_row: ?usize = null;

    for (parsed.value.array.items, 0..) |value, index| {
        if (accounting.counts.contains(index)) continue;
        _ = value;
        uncovered_count += 1;
        if (first_missing_row == null) first_missing_row = index;
    }

    try std.testing.expectEqual(@as(usize, 0), accounting.duplicate_count);
    try std.testing.expectEqual(@as(?usize, null), accounting.first_duplicate_row);
    try std.testing.expectEqual(@as(usize, 0), uncovered_count);
    try std.testing.expectEqual(@as(?usize, null), first_missing_row);
}
