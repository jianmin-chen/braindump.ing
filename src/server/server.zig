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

    server.dispatcher(cors);

    var router = server.router();
    router.get("/", index);
    router.post("/subscribe", subscribe);
    router.get("/comments/:slug", get_comments);
    router.post("/comment", submit_comment);

    std.debug.print("Server listening on port {d}\n", .{port});
    try server.listen();
}

fn cors(action: httpz.Action(void), req: *Request, res: *Response) !void {
    res.header("Access-Control-Allow-Origin", "*");
    return action(req, res);
}

fn index(_: *Request, res: *Response) !void {
    std.debug.print("/ pinged\n", .{});
    res.body = "hello, world!";
}

fn subscribe(req: *Request, res: *Response) !void {
    const submission = try req.formData();
    if (submission.get("email")) |email| {
        try res.json(.{ .email = email, .success = false }, .{});
        return;
    }

    try res.json(.{ .success = false }, .{});
}

fn get_comments(_: *Request, res: *Response) !void {
  try res.json(.{
    .{
      .name = "Min4Builder",
      .comment = "Another interesting language to look at is the Plan 9 dialect of C. There, structs can contain struct fields with no name, and will be casted automatically. This is where Go got the idea from. If a struct starts with another nameless struct, pointers to it are covariant. This is used for several things in Plan 9, like the Refcount type (adds reference counting to some other type) or the Lock and Mutex types (similar). Oberon also has similar rules, if I'm not mistaken.Minor correction: SML does have polymorphism. It doesn't have variance because that makes the type inference tricky, and actually many implementations have uniform representations for the polymorphism (MLton doesn't, but then it monomorphizes everything). So it wouldn't fit the same category as C and Pascal.",
      .comments = .{
        .{
          .name = "munificent",
          .comment = "Thanks, changed the mention of SML to Pascal."
        }
      }
    },
    .{
      .name = "Angelo Ceccato",
      .comment = "Hi Robert! I appreciate your post; it gave me an interesting perspective on the Go type system. However, I must admit that I'm quite ignorant about it. Are the trade-offs between Java and Go significantly different from those between languages like TypeScript (apart from the runtime level)? Also, how does Go differ from what I've read about row polymorphism or structural polymorphism? Any insights to help me understand these topics better would be great!",
      .comments = .{}
    }
  }, .{});
}

fn submit_comment(req: *Request, res: *Response) !void {
    const submission = try req.formData();
    if (submission.get("response_id")) |response_id| {
        // Comment is a response to another comment.
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
