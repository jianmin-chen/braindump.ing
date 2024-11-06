const std = @import("std");
const datetime = @import("datetime.zig");
const md = @import("md");
const Template = @import("template.zig");
const server = @import("server/server.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);
const fs = std.fs;
const assert = std.debug.assert;
const panic = std.debug.panic;

const Element = md.Element;
const plugins = md.plugins;

const Opt = enum { build, serve };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var opt: Opt = .build;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    if (args.next()) |opt_arg| {
        if (std.mem.eql(u8, opt_arg, "--serve")) opt = .serve;
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

            // TODO: Eventually replace with XML style writer
            const feed_path = try fs.path.join(allocator, &[_][]const u8{ Template.output_dir, "atom.xml" });
            defer allocator.free(feed_path);
            var feed = try fs.cwd().createFile(feed_path, .{});
            defer feed.close();
            const writer = feed.writer();

            const date = try @constCast(&try datetime.fromTimestamp(allocator, std.time.timestamp())).toString();
            defer allocator.free(date);
            try writer.print(
                \\<feed xmlns="https://www.w3.org/2005/Atom">
                \\  <title>braindump.ing</title>
                \\  <link href="https://braindump.ing/atom.xml" ref="self"/>
                \\  <link href="https://braindump.ing"/>
                \\  <updated>{s}</updated>
                \\  <id>braindump.ing</id>
                \\  <author>
                \\    <name>JC</name>
                \\  </author>
                , .{date}
            );

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
                try output(allocator, entry, prev, next, &feed);
            }

            _ = try writer.write("</feed>");
        },
        .serve => try server.start(allocator)
    }
}

const Backlink = struct {
    allocator: Allocator,

    fn init(allocator: Allocator) Backlink {
        return .{ .allocator = allocator };
    }

    pub fn operate(self: *Backlink, ast: *Element) !void {
        for (ast.children.items) |child| {
            if (std.mem.startsWith(u8, child.name, "h")) {
                const slug = child.props.get("data-slug") orelse unreachable;
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
};

fn output(allocator: Allocator, entry: []const u8, prev: ?[]const u8, next: ?[]const u8, feed: *fs.File) !void {
    const input_path = try fs.path.join(allocator, &[_][]const u8{ Template.input_dir, entry });
    defer allocator.free(input_path);

    const file = try fs.cwd().openFile(input_path, .{});
    defer file.close();

    const raw = try allocator.alloc(u8, try file.getEndPos());
    _ = try file.readAll(raw);
    defer allocator.free(raw);

    var toc = plugins.TableOfContents.init(allocator, .{});
    defer toc.deinit();

    var backlink = Backlink.init(allocator);

    var converted = try md.toHtml(allocator, raw, .{&toc, &backlink});
    defer converted.deinit();

    if (converted.frontmatter.get("title") == null)
        panic("Expected title in {s}.\n", .{entry});
    if (converted.frontmatter.get("date") == null)
        panic("Expected date in {s}.\n", .{entry});
    if (converted.frontmatter.get("description") == null)
        panic("Expected description in {s}.\n", .{entry});

    const title = converted.frontmatter.get("title") orelse unreachable;
    const slug = std.mem.trim(u8, entry, ".md");

    const date = converted.frontmatter.get("date") orelse unreachable;
    var it = std.mem.splitScalar(u8, date, '-');
    const year = it.next() orelse unreachable;
    const month = it.next() orelse unreachable;
    const day = it.next() orelse unreachable;
    const formatted_date = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{month, day, year});
    defer allocator.free(formatted_date);

    const feed_writer = feed.writer();
    try feed_writer.print(
        \\<entry>
        \\  <title type="html">{s}</title>
        \\  <link href="https://braindump.ing/{s}.html"/>
        \\  <id>https://braindump.ing/{s}.html</id>
        \\  <updated>{s}T00:00:00Z</updated>
        \\</entry>
        , .{title, slug, slug, date}
    );

    const template_path = try fs.path.join(allocator, &[_][]const u8{ Template.static_dir, "[slug].html" });
    defer allocator.free(template_path);

    const html = try std.fmt.allocPrint(allocator, "{s}.html", .{slug});
    defer allocator.free(html);
    const output_path = try fs.path.join(allocator, &[_][]const u8{ Template.output_dir, Template.post_dir, html });
    defer allocator.free(output_path);

    var template = Template.create(allocator, template_path);
    defer template.deinit();

    try template.add_expression("slug", slug);
    try template.add_expression("title", title);
    try template.add_expression("date", formatted_date);
    try template.add_expression("post", converted.output);

    var nav = ArrayList(u8).init(allocator);
    defer nav.deinit();
    if (prev != null or next != null) {
        const writer = nav.writer();
        _ = try writer.write("<nav>");

        if (prev) |filename| {
            const url = try std.fmt.allocPrint(allocator, "post/{s}.html", .{std.mem.trim(u8, filename, ".md")});
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
                \\  <a href="/{s}">
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
            std.debug.print("{s}\n", .{filename});
            const url = try std.fmt.allocPrint(allocator, "post/{s}.html", .{std.mem.trim(u8, filename, ".md")});
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
                \\  <a href="/{s}">
                \\    <span>{s}</span>
                \\    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-corner-down-right"><polyline points="15 10 20 15 15 20"></polyline><path d="M4 4v7a4 4 0 0 0 4 4h12"></path></svg>
                \\  </a>
                \\</p>
                , .{url, parsed.frontmatter.get("title") orelse unreachable}
            );
        }

        _ = try writer.write("</nav>");
        try template.add_expression("nav", nav.items);
    } else try template.add_expression("nav", "<nav><p></p></nav>");

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

    const toc_expr = try tocToHtml(allocator, &toc);
    defer allocator.free(toc_expr);
    try template.add_expression("toc", toc_expr);

    // Compile SEO
    const meta_path = try fs.path.join(allocator, &[_][]const u8{ Template.static_dir, "seo.html" });
    defer allocator.free(meta_path);

    var meta = Template.create(allocator, meta_path);
    defer meta.deinit();

    try meta.add_expression("title", title);
    try meta.add_expression("description", converted.frontmatter.get("description") orelse unreachable);
    try meta.add_expression("slug", slug);
    try meta.add_expression("timestamp", date);

    try meta.output();
    try template.add_expression("meta", meta.template);

    try template.output();
    try template.save(output_path);
    if (next == null) {
        const index_path = try fs.path.join(allocator, &[_][]const u8{ Template.output_dir, "index.html" });
        defer allocator.free(index_path);
        try template.save(index_path);
    }
}

fn tocToHtml(allocator: Allocator, toc: *plugins.TableOfContents) ![]u8 {
    const wrapper = try Element.init(allocator, "div");
    defer wrapper.deinit();

    for (toc.slugs.items, 0..) |slug, idx| {
        const value = toc.values.items[idx];
        const p = try Element.init(allocator, "p");
        const backlink = try Element.init(allocator, "a");
        try backlink.addProp("href", slug);
        try backlink.addChild(
            try Element.textNode(
                allocator,
                std.mem.trim(u8, value, " ")
            )
        );
        try p.addChild(backlink);
        try wrapper.addChild(p);
    }

    var html = ArrayList(u8).init(allocator);
    defer html.deinit();
    try wrapper.toHtml(html.writer());
    return html.toOwnedSlice();
}
