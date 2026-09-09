const std = @import("std");

var test_threaded: ?std.Io.Threaded = null;

fn testIo() std.Io {
    if (test_threaded == null) {
        test_threaded = std.Io.Threaded.init(std.testing.allocator, .{ .environ = .empty });
    }
    return test_threaded.?.io();
}

const ExternalInput = struct {
    name: []const u8,
    path: []const u8,
    purpose: []const u8,
    optional_step: ?[]const u8 = null,
};

const external_inputs = [_]ExternalInput{
    .{
        .name = "Go script corpus",
        .path = "../go-sdk/script/interpreter/data/script_tests.json",
        .purpose = "exact/filtered Go interpreter corpus suites",
    },
};

pub fn envRequiresExternalCoverage(allocator: std.mem.Allocator) bool {
    // Zig 0.16 removed std.process.getEnvVarOwned; without libc the process
    // environment is only reachable via /proc/self/environ on Linux.
    if (@import("builtin").os.tag != .linux) return false;
    const io = testIo();
    var proc_dir = std.Io.Dir.openDirAbsolute(io, "/proc/self", .{}) catch return false;
    defer proc_dir.close(io);
    const data = proc_dir.readFileAlloc(io, "environ", allocator, .limited(1024 * 1024)) catch return false;
    defer allocator.free(data);

    var it = std.mem.splitScalar(u8, data, 0);
    while (it.next()) |entry| {
        const eq = std.mem.indexOfScalar(u8, entry, '=') orelse continue;
        if (!std.mem.eql(u8, entry[0..eq], "BSVZ_REQUIRE_EXTERNAL_CORPORA")) continue;
        const value = entry[eq + 1 ..];
        return std.mem.eql(u8, value, "1") or
            std.ascii.eqlIgnoreCase(value, "true") or
            std.ascii.eqlIgnoreCase(value, "yes");
    }
    return false;
}

test "external corpus availability is visible in default test runs" {
    const allocator = std.testing.allocator;
    const require_external = envRequiresExternalCoverage(allocator);
    var missing_count: usize = 0;

    std.debug.print(
        "external coverage note: set BSVZ_REQUIRE_EXTERNAL_CORPORA=1 to fail when optional corpora are missing\n",
        .{},
    );

    for (external_inputs) |input| {
        std.Io.Dir.cwd().access(testIo(), input.path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                missing_count += 1;
                if (input.optional_step) |step| {
                    std.debug.print(
                        "warning: missing optional external input '{s}' at {s}; {s} will not run in default coverage ({s})\n",
                        .{ input.name, input.path, step, input.purpose },
                    );
                } else {
                    if (require_external) {
                        std.debug.print(
                            "error: missing required external input '{s}' at {s}; default coverage is incomplete without it ({s})\n",
                            .{ input.name, input.path, input.purpose },
                        );
                        return error.MissingExternalCoverageInputs;
                    }
                    std.debug.print(
                        "warning: missing external input '{s}' at {s}; related tests will skip ({s})\n",
                        .{ input.name, input.path, input.purpose },
                    );
                }
                continue;
            },
            else => return err,
        };

        std.debug.print("external coverage input present: {s} ({s})\n", .{ input.name, input.purpose });
    }

    std.debug.print(
        "coverage note: filtered Go corpus lanes now execute dynamic rows and report any remaining meta-row skips in test stderr\n",
        .{},
    );

    if (require_external and missing_count != 0) return error.MissingExternalCoverageInputs;
}
