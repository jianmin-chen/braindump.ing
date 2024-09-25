const std = @import("std");
const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const TableOfContents = struct {
    allocator: Allocator,
    slugs: ArrayList([]const u8),
    mutate: bool = true,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .slugs = ArrayList([]const u8).init(allocator)
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.slugs.items) |slug| {
            self.allocator.free(slug);
        }
        self.slugs.deinit();
    }

    pub fn operate(self: *Self, ast: *Element) !void {
        _ = self;
        for (ast.children.items) |child| {
            if (std.mem.startsWith(u8, child.name, "h")) {
                // var hash = ArrayList(u8).init(self.allocator);
                // defer hash.deinit();
                // try @constCast(&child).toText(&hash);
                // try self.id(&hash);

                // try self.slugs.append(hash.items);
                // const ref = self.slugs.items[self.slugs.items.len - 1];

                try @constCast(&child).addProp("id", "test");
            }
        }
    }

    fn id(self: *Self, hash: *ArrayList(u8)) !void {
        hash.items[0] = '#';
        var i: usize = 1;
        while (i < hash.items.len) {
            if (hash.items[i] == ' ') {
                hash.items[i] = '-';
            } else if (!std.ascii.isAlphabetic(hash.items[i])) {
                _ = hash.orderedRemove(i);
                continue;
            }

            hash.items[i] = std.ascii.toLower(hash.items[i]);
            i += 1;
        }

        const slice: []const u8 = hash.items;
        var idx: usize = 0;
        for (self.slugs.items) |slug| {
            if (std.mem.startsWith(u8, slug, slice))
                idx += 1;
        }

        if (idx > 0) {
            const writer = hash.writer();
            try writer.print("{d}", .{idx});
        }
    }
};
