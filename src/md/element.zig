const std = @import("std");
const escape = @import("utils.zig").escape;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);

const Self = @This();

name: []const u8,
props: StringHashMap,
children: ArrayList(Self),

pub fn init(allocator: Allocator, name: []const u8) Self {
    return .{
        .name = name,
        .props = StringHashMap.init(allocator),
        .children = ArrayList(Self).init(allocator)
    };
}

pub fn deinit(self: *Self) void {
    self.props.deinit();
    for (self.children.items) |child| {
        @constCast(&child).deinit();
    }
    self.children.deinit();
}

pub fn textNode(allocator: Allocator, text: []const u8) !Self {
    var text_node = Self.init(allocator, "");
    try text_node.addProp("nodeValue", text);
    return text_node;
}

pub fn addProp(self: *Self, k: []const u8, v: []const u8) !void {
    try self.props.put(k, v);
}

pub fn addChild(self: *Self, child: Self) !void {
    try self.children.append(child);
}

pub fn toHtml(self: *Self, output: *ArrayList(u8)) !void {
    const writer = output.writer();

    if (self.props.get("nodeValue")) |node_value| {
        try escape(node_value, output);
        return;
    }

    const contained: bool = self.children.items.len == 0;
    if (contained) {
        try writer.print("<{s}", .{self.name});

        var keys = self.props.keyIterator();
        while (keys.next()) |k| {
            const v = self.props.get(k.*) orelse unreachable;
            try writer.print(" {s}=\"{s}\"", .{k.*, v});
        }

        try writer.print("/>", .{});
        return;
    }

    try writer.print("<{s}", .{self.name});

    var keys = self.props.keyIterator();
    while (keys.next()) |k| {
        const v = self.props.get(k.*) orelse unreachable;
        try writer.print(" {s}=\"{s}\"", .{k.*, v});
    }
    try writer.print(">", .{});

    for (self.children.items) |child| {
        try @constCast(&child).toHtml(output);
    }

    try writer.print("</{s}>", .{self.name});
}
