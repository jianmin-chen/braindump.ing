const std = @import("std");
const Element = @import("element.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const TableOfContents = struct {
    allocator: Allocator,
    slugs: ArrayList([]const u8),
    values: ArrayList([]const u8),
    mutate: bool = true,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .slugs = ArrayList([]const u8).init(allocator),
            .values = ArrayList([]const u8).init(allocator)
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.slugs.items) |slug| {
            self.allocator.free(slug);
        }
        self.slugs.deinit();
        for (self.values.items) |value| {
            self.allocator.free(value);
        }
        self.values.deinit();
    }

    pub fn toHtml(self: *Self) ![]u8 {
        var toc = Element.init(self.allocator, "div");
        defer toc.deinit();

        for (self.slugs.items, 0..) |slug, idx| {
            const value = self.values.items[idx];
            var p = Element.init(self.allocator, "p");
            var backlink = Element.init(self.allocator, "a");
            try backlink.addProp("href", slug);
            try backlink.addChild(
                try Element.textNode(
                    self.allocator,
                    std.mem.trim(u8, value, " ")
                )
            );
            try p.addChild(backlink);
            try toc.addChild(p);
        }

        var html = ArrayList(u8).init(self.allocator);
        defer html.deinit();
        try toc.toHtml(&html);
        return html.toOwnedSlice();
    }

    pub fn operate(self: *Self, ast: Element) !void {
        for (ast.children.items) |child| {
            if (std.mem.startsWith(u8, child.name, "h")) {
                var node_value = ArrayList(u8).init(self.allocator);
                defer node_value.deinit();
                try @constCast(&child).toText(&node_value);

                try self.id(&node_value);

                const slug = self.slugs.items[self.slugs.items.len - 1];
                _ = slug;
            }
        }
    }

    fn id(self: *Self, node_value: *ArrayList(u8)) !void {
        var hash = try node_value.clone();
        defer hash.deinit();

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

        const idx: usize = 0;
        if (idx > 0) {
            const writer = hash.writer();
            try writer.print("{d}", .{idx});
        }

        try self.slugs.append(try hash.toOwnedSlice());
        try self.values.append(try node_value.toOwnedSlice());
    }
};
