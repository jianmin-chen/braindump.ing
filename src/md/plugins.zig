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
        const toc = try Element.init(self.allocator, "div");
        defer toc.deinit();

        for (self.slugs.items, 0..) |slug, idx| {
            const value = self.values.items[idx];
            const p = try Element.init(self.allocator, "p");
            const backlink = try Element.init(self.allocator, "a");
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

    pub fn operate(self: *Self, ast: *Element) !void {
        for (ast.children.items) |child| {
            if (std.mem.startsWith(u8, child.name, "h")) {
                var node_value = ArrayList(u8).init(self.allocator);
                defer node_value.deinit();
                try child.toText(&node_value);

                try self.id(&node_value);

                const slug = self.slugs.items[self.slugs.items.len - 1];
                try child.addProp("id", std.mem.trim(u8, slug, "#"));

                const backlink = try Element.init(self.allocator, "a");
                try backlink.addProp("class", "link");
                try backlink.addProp("href", slug);
                try backlink.addChild(
                    try Element.htmlNode(
                        self.allocator,
                        \\<svg stroke="currentColor" fill="none" stroke-width="2" viewBox="0 0 24 24" stroke-linecap="round" stroke-linejoin="round" height="1em" width="1em" xmlns="http://www.w3.org/2000/svg"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"></path><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"></path></svg>
                    )
                );
                try child.addChild(backlink);
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
