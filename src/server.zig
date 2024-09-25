const std = @import("std");
const httpz = @import("httpz");

const Allocator = std.mem.Allocator;

const Request = httpz.Request;
const Response = httpz.Response;

const port = 5000;

pub fn start(allocator: Allocator) !void {
    var server = try httpz.Server().init(allocator, .{
        .port = port,
        .request = .{
            .max_form_count = 5
        }
    });
    defer server.deinit();
    defer server.stop();

    var router = server.router();
    router.get("/", index);
    router.post("/subscribe", subscribe);
    router.post("/comment", submit_comment);

    std.debug.print("Server listening on port {d}\n", .{port});
    try server.listen();
}

fn index(_: *Request, res: *Response) !void {
    res.body = "hello, world!";
}

fn subscribe(req: *Request, res: *Response) !void {
    const submission = try req.formData();
    if (submission.get("email")) |email| {
        try res.json(.{ .email = email }, .{});
        return;
    }

    try res.json(.{ .success = false }, .{});
}

fn submit_comment(req: *Request, res: *Response) !void {
    const submission = try req.formData();
    if (submission.get("response_id")) |response_id| {
        // Comment is a response to another comment
        _ = response_id;
        try res.json(.{ .success = true }, .{});
        return;
    }

    const name = submission.get("name") orelse {
        try res.json(.{ .success = false }, .{});
        return;
    };

    const comment = submission.get("comment") orelse {
        try res.json(.{ .success = false }, .{});
        return;
    };

    std.debug.print("{s} {s}\n", .{name, comment});
    try res.json(.{ .success = true }, .{});

    return;
}

fn is_spam(s: []const u8) bool {
    _ = s;
    return true;
}
