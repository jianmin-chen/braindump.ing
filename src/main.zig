const std = @import("std");
const Element = @import("md/element.zig");
const md = @import("md/md.zig");
const plugins = @import("md/plugins.zig");
const Template = @import("template.zig");
const server = @import("server/server.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);
const fs = std.fs;
const assert = std.debug.assert;
const panic = std.debug.panic;

const Opt = enum { build, serve };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var opt: Opt = .serve;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    if (args.next()) |opt_arg| {
        if (std.mem.eql(u8, opt_arg, "--build")) opt = .build;
    }

    switch (opt) {
        .build => {
            var output_dir = try fs.cwd().openDir(Template.output_dir, .{});
            defer output_dir.close();

            try output_dir.deleteTree(Template.post_dir);
            try output_dir.makeDir(Template.post_dir);

            var input_dir = try fs.cwd().openDir(Template.input_dir, .{});
            defer input_dir.close();

            var sorted = ArrayList([]const u8).init(allocator);
            defer sorted.deinit();

            var it = input_dir.iterate();
            while (try it.next()) |entry| {
                if (sorted.items.len != 0) {
                    var slot: usize = 0;
                    while (slot < sorted.items.len) {
                        const cmp = sorted.items[slot];
                        if (std.mem.order(u8, entry.name, cmp) == .lt) break;
                        slot += 1;
                    }
                    try sorted.insert(slot, entry.name);
                } else try sorted.append(entry.name);
            }

            for (sorted.items, 0..) |entry, idx| {
                const prev: ?[]const u8 = if (idx != 0) sorted.items[idx - 1] else null;
                const next: ?[]const u8 = if (idx != sorted.items.len - 1) sorted.items[idx + 1] else null;
                try output(allocator, entry, prev, next);
            }
        },
        .serve => try server.start(allocator)
    }
}

fn output(allocator: Allocator, entry: []const u8, prev: ?[]const u8, next: ?[]const u8) !void {
    const input_path = try fs.path.join(allocator, &[_][]const u8{ Template.input_dir, entry });
    defer allocator.free(input_path);

    const file = try fs.cwd().openFile(input_path, .{});
    defer file.close();

    const raw = try allocator.alloc(u8, try file.getEndPos());
    _ = try file.readAll(raw);
    defer allocator.free(raw);

    var toc = plugins.TableOfContents.init(allocator);
    defer toc.deinit();

    var converted = try md.toHtml(allocator, raw, .{&toc});
    defer converted.deinit();

    if (converted.frontmatter.get("title") == null)
        panic("Expected title in {s}.\n", .{entry});
    if (converted.frontmatter.get("date") == null)
        panic("Expected date in {s}.\n", .{entry});

    const template_path = try fs.path.join(allocator, &[_][]const u8{ Template.static_dir, "[slug].html" });
    defer allocator.free(template_path);

    const html = try std.fmt.allocPrint(allocator, "{s}.html", .{std.mem.trim(u8, entry, ".md")});
    defer allocator.free(html);
    const output_path = try fs.path.join(allocator, &[_][]const u8{ Template.output_dir, Template.post_dir, html });
    defer allocator.free(output_path);

    var template = Template.create(allocator, template_path);
    defer template.deinit();

    try template.add_expression("slug", std.mem.trim(u8, entry, ".md"));
    try template.add_expression("title", converted.frontmatter.get("title") orelse unreachable);
    try template.add_expression("post", converted.output);

    var nav = ArrayList(u8).init(allocator);
    defer nav.deinit();
    if (prev != null or next != null) {
        const writer = nav.writer();
        _ = try writer.write("<nav>");

        if (prev) |filename| {
            const url = try std.fmt.allocPrint(allocator, "/post/{s}.html", .{std.mem.trim(u8, filename, ".md")});
            defer allocator.free(url);

            const path = try fs.path.join(allocator, &[_][]const u8{ Template.input_dir, filename });
            defer allocator.free(path);

            const prev_file = try fs.cwd().openFile(path, .{});
            defer prev_file.close();

            const prev_raw = try allocator.alloc(u8, try prev_file.getEndPos());
            _ = try prev_file.readAll(prev_raw);
            defer allocator.free(prev_raw);

            var parsed = try md.toFrontmatter(allocator, prev_raw);
            defer parsed.deinit();

            try writer.print(
                \\<p>
                \\  <a href="{s}">
                \\    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-corner-down-left"><polyline points="9 10 4 15 9 20"></polyline><path d="M20 4v7a4 4 0 0 1-4 4H4"></path></svg>
                \\    <span>{s}</span>
                \\  </a>
                \\</p>
                , .{url, parsed.frontmatter.get("title") orelse unreachable}
            );
        } else {
            try writer.print("<p></p>", .{});
        }

        if (next) |filename| {
            const url = try std.fmt.allocPrint(allocator, "{s}.html", .{std.mem.trim(u8, filename, ".md")});
            defer allocator.free(url);

            const path = try fs.path.join(allocator, &[_][]const u8{ Template.input_dir, filename });
            defer allocator.free(path);

            const next_file = try fs.cwd().openFile(path, .{});
            defer next_file.close();

            const next_raw = try allocator.alloc(u8, try next_file.getEndPos());
            _ = try next_file.readAll(next_raw);
            defer allocator.free(next_raw);

            var parsed = try md.toFrontmatter(allocator, next_raw);
            defer parsed.deinit();

            if (parsed.frontmatter.get("title") == null)
                panic("Expected title in {s}.\n", .{filename});

            try writer.print(
                \\<p>
                \\  <a href="{s}">
                \\    <span>{s}</span>
                \\    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-corner-down-right"><polyline points="15 10 20 15 15 20"></polyline><path d="M4 4v7a4 4 0 0 0 4 4h12"></path></svg>
                \\  </a>
                \\</p>
                , .{url, parsed.frontmatter.get("title") orelse unreachable}
            );
        }

        _ = try writer.write("</nav>");
        try template.add_expression("nav", nav.items);
    } else try template.add_expression("nav", "");

    // const hackernews = converted.frontmatter.get("hackernews") orelse "";
    // const html = try std.fmt.allocPrint(
    //     allocator,
    //     "<p>View the discussion on <a href='https://news.ycombinator.com/item?id={s}'>Hacker News</a>.</p>",
    //     .{hackernews}
    // );
    // defer allocator.free(html);
    // if (hackernews.len == 0) {
    //     try template.add_expression("hackernews", "");
    // } else
    //     try template.add_expression("hackernews", html);

    const toc_expr = try toc.toHtml();
    defer allocator.free(toc_expr);
    try template.add_expression("toc", toc_expr);

    try template.output();
    try template.save(output_path);
    if (next == null) {
        const index_path = try fs.path.join(allocator, &[_][]const u8{ Template.output_dir, "index.html" });
        defer allocator.free(index_path);
        try template.save(index_path);
    }
}
