const std = @import("std");
const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const TableOfContents = struct {
    slugs: ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .slugs = ArrayList([]const u8).init(allocator)
        };
    }

    pub fn deinit(self: *Self) void {
        self.slugs.deinit();
    }

    pub fn operate(self: *Self, ast: *Element) !void {
        _ = self;
        _ = ast;
    }
};
