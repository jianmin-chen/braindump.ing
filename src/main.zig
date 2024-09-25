const std = @import("std");
const md = @import("md/md.zig");
const Template = @import("template.zig");
const server = @import("server.zig");

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap([]const u8);
const assert = std.debug.assert;
const panic = std.debug.panic;

const Opt = enum {
    build,
    serve
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var opt: Opt = .serve;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    if (args.next()) |opt_arg| {
        if (std.mem.eql(u8, opt_arg, "--build")) {
            opt = .build;
        }
    }

    switch (opt) {
        .build => {
            var inp = try std.fs.cwd().openDir(Template.input_dir, .{});
            defer inp.close();

            var it = inp.iterate();
            while (try it.next()) |entry| {
                try output(allocator, entry.name);
            }
        },
        .serve => {
            try server.start(allocator);
        }
    }
}

fn output(allocator: Allocator, entry: []const u8) !void {
    const input_path = try std.fs.path.join(allocator, &[_][]const u8{
        Template.input_dir,
        entry
    });
    defer allocator.free(input_path);

    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const buf = try allocator.alloc(u8, try file.getEndPos());
    _ = try file.readAll(buf);
    defer allocator.free(buf);

    var converted = try md.toHtml(allocator, buf);
    defer converted.deinit();

    if (converted.frontmatter.get("title") == null)
        panic("Expected title in {s}.\n", .{entry});

    const template_path = try std.fs.path.join(allocator, &[_][]const u8{
        Template.static_dir,
        "[slug].html"
    });
    defer allocator.free(template_path);

    const filename = try std.fmt.allocPrint(allocator, "{s}.html", .{std.mem.trim(u8, entry, ".md")});
    defer allocator.free(filename);
    const output_path = try std.fs.path.join(allocator, &[_][]const u8{
        Template.output_dir,
        Template.post_dir,
        filename
    });
    defer allocator.free(output_path);

    var template = Template.create(allocator, template_path, output_path);
    defer template.deinit();

    try template.add_expression("title", converted.frontmatter.get("title") orelse unreachable);
    try template.add_expression("post", converted.output);

    const hackernews = converted.frontmatter.get("hackernews") orelse "";
    const html = try std.fmt.allocPrint(
        allocator,
        "<p>View the discussion on <a href='https://news.ycombinator.com/item?id={s}'>Hacker News</a>.</p>",
        .{hackernews}
    );
    defer allocator.free(html);
    if (hackernews.len == 0) {
        try template.add_expression("hackernews", "");
    } else
        try template.add_expression("hackernews", html);

    try template.output();
}
