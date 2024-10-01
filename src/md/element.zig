const std = @import("std");
const escape = @import("utils.zig").escape;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);

const Self = @This();

allocator: Allocator,
name: []const u8,
props: StringHashMap,
children: ArrayList(*Self),

pub fn init(allocator: Allocator, name: []const u8) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .allocator = allocator,
        .name = name,
        .props = StringHashMap.init(allocator),
        .children = ArrayList(*Self).init(allocator)
    };
    return self;
}

pub fn deinit(self: *Self) void {
    self.props.deinit();
    for (self.children.items) |child| {
        child.deinit();
    }
    self.children.deinit();
    self.allocator.destroy(self);
}

pub fn htmlNode(allocator: Allocator, html: []const u8) !*Self {
    const node = try Self.init(allocator, "");
    try node.addProp("htmlValue", html);
    return node;
}

pub fn textNode(allocator: Allocator, text: []const u8) !*Self {
    const node = try Self.init(allocator, "");
    try node.addProp("nodeValue", text);
    return node;
}

pub fn addProp(self: *Self, k: []const u8, v: []const u8) !void {
    try self.props.put(k, v);
}

pub fn addChild(self: *Self, child: *Self) !void {
    try self.children.append(child);
}

pub fn toText(self: *Self, output: *ArrayList(u8)) !void {
    const writer = output.writer();

    if (self.props.get("nodeValue")) |node_value| {
        try writer.print("{s}", .{node_value});
        return;
    }

    for (self.children.items) |child| {
        try child.toText(output);
    }
}

pub fn toHtml(self: *Self, output: *ArrayList(u8)) !void {
    const writer = output.writer();

    if (self.props.get("nodeValue")) |node_value| {
        try escape(node_value, output);
        return;
    } else if (self.props.get("htmlValue")) |html_value| {
        try writer.print("{s}", .{html_value});
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
        try child.toHtml(output);
    }

    try writer.print("</{s}>", .{self.name});
}
