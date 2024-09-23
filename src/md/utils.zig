const std = @import("std");

const ArrayList = std.ArrayList;

pub fn escape(s: []const u8, output: *ArrayList(u8)) !void {
    const writer = output.writer();
    // const old = [_]u8{ "<" , ">", "&", "\"" };
    const old = [_]u8{ '<', '>', '&', '"' };
    const replacements = [_][]const u8{ "&lt;", "&gt;", "&amp;", "&quot;" };
    for (s) |chr| {
        var idx: ?usize = null;
        for (old, 0..) |cmp, i| {
            if (chr == cmp) {
                idx = i;
                break;
            }
        }
        if (idx) |index| {
            const replace = replacements[index];
            try writer.print("{s}", .{replace});
        } else
            try writer.print("{c}", .{chr});
    }
}
