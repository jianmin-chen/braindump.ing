const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);
const panic = std.debug.panic;

pub const input_dir = "content";
pub const static_dir = "include";
pub const output_dir = "out";
pub const post_dir = "post";

const Self = @This();

allocator: Allocator,
expressions: StringHashMap,
template_path: []const u8,
template: []u8 = undefined,

pub fn create(allocator: Allocator, template_path: []const u8) Self {
    return .{
        .allocator = allocator,
        .expressions = StringHashMap.init(allocator),
        .template_path = template_path
    };
}

pub fn deinit(self: *Self) void {
    self.expressions.deinit();
    self.allocator.free(self.template);
}

pub fn add_expression(self: *Self, k: []const u8, v: []const u8) !void {
    try self.expressions.put(k, v);
}

pub fn output(self: *Self) !void {
    const template_file = try std.fs.cwd().openFile(self.template_path, .{});
    defer template_file.close();

    const template = try self.allocator.alloc(u8, try template_file.getEndPos());
    _ = try template_file.readAll(template);
    defer self.allocator.free(template);

    var replace: []u8 = try std.fmt.allocPrint(self.allocator, "{s}", .{template});

    var keys = self.expressions.keyIterator();
    while (keys.next()) |k| {
        // Search in `template` for {{ `k` }} and replace it with `v`.
        const needle = try std.fmt.allocPrint(self.allocator, "{{{{ {s} }}}}", .{k.*});
        defer self.allocator.free(needle);

        while (std.mem.indexOf(u8, replace, needle)) |index| {
            const v = self.expressions.get(k.*) orelse unreachable;

            const before = replace[0..index];
            const after = replace[index + needle.len..];
            const new = try self.allocator.alloc(u8, before.len + after.len + v.len);
            _ = try std.fmt.bufPrint(new, "{s}{s}{s}", .{before, v, after});
            self.allocator.free(replace);
            replace = new;
        }
    }

    self.template = replace;
}

pub fn save(self: *Self, path: []const u8) !void {
    const wrapper_path = try std.fs.path.join(self.allocator, &[_][]const u8{ static_dir, "wrapper.html" });
    defer self.allocator.free(wrapper_path);

    var wrapper = Self.create(self.allocator, wrapper_path);
    defer wrapper.deinit();

    try wrapper.add_expression("template", self.template);
    try wrapper.add_expression("meta", self.expressions.get("meta") orelse "");

    try wrapper.output();

    const formatted = try std.fs.cwd().createFile(path, .{});
    defer formatted.close();

    _ = try formatted.write(wrapper.template);
}
