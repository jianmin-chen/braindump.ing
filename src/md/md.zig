const std = @import("std");
const Element = @import("element.zig");
const plugins = @import("plugins.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap([]const u8);
const assert = std.debug.assert;
const panic = std.debug.panic;

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " ");
}

pub const TokenType = enum {
    blockquote,
    frontmatter,
    heading,
    colon,
    exclaim,
    bracket,
    paren,
    code,
    code_block,
    italic,
    bold,
    plain,
    nl,
    eof
};

const delimiters = [_]u8{ '>', '-', '#', ':', '!', '[', ']', '(', ')', '`', '*', '\n' };

const Token = struct {
    kind: TokenType,
    start: usize,
    length: usize
};

pub const Lexer = struct {
    raw: []const u8,
    start: usize,
    current: usize,
    col: usize,
    tokens: ArrayList(Token),

    fn init(allocator: Allocator, raw: []const u8) Lexer {
        return .{
            .raw = raw,
            .start = 0,
            .current = 0,
            .col = 0,
            .tokens = ArrayList(Token).init(allocator)
        };
    }

    fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    fn tokenize(self: *Lexer) !ArrayList(Token) {
        while (!self.isAtEnd()) {
            try self.scanToken();
        }
        self.start = self.current;
        try self.addToken(.eof);
        return self.tokens;
    }

    fn addToken(self: *Lexer, kind: TokenType) !void {
        try self.tokens.append(Token{
            .kind = kind,
            .start = self.start,
            .length = self.current - self.start
        });
    }

    fn scanToken(self: *Lexer) !void {
        self.start = self.current;
        const chr = self.advance();
        switch (chr) {
            '-' => {
                if (self.col == 1 and self.peek() == '-' and self.peekAhead(1) == '-') {
                    _ = self.advance();
                    _ = self.advance();
                    try self.addToken(.frontmatter);
                } else
                    try self.addToken(.plain);
            },
            '`' => {
                if (self.col == 1 and self.peek() == '`' and self.peekAhead(1) == '`') {
                    _ = self.advance();
                    _ = self.advance();
                    while (self.peek() != '`' and self.peekAhead(1) != '`' and self.peekAhead(2) != '`') {
                        _ = self.advance();
                        if (self.raw.len - self.current < 3) {
                            try self.addToken(.plain);
                            return;
                        }
                    }
                    _ = self.advance();
                    _ = self.advance();
                    _ = self.advance();
                    try self.addToken(.code_block);
                    return;
                }
                try self.wrap(.code, '`');  // `` is not a recursive element
            },
            '*' => {
                try self.wrap(.italic, '*');
            },
            '#' => {
                while (self.peek() == '#') {
                    _ = self.advance();
                    if (self.isAtEnd()) {
                        try self.addToken(.plain);
                        return;
                    }
                }

                if (self.peek() == ' ' and self.current - self.start <= 6) {
                    try self.addToken(.heading);
                } else {
                    try self.addToken(.plain);
                }
            },
            '!' => {
                try self.addToken(.exclaim);
            },
            '[' => {
                try self.wrap(.bracket, ']');
            },
            '(' => {
                try self.wrap(.paren, ')');
            },
            '>' => {
                if (self.col == 1 and self.peek() == ' ') {
                    _ = self.advance();
                    try self.addToken(.blockquote);
                }
            },
            ':' => {
                try self.addToken(.colon);
            },
            '\n' => {
                try self.addToken(.nl);
                self.col = 0;
            },
            else => {
                while (!self.identifier()) {
                    _ = self.advance();
                    if (self.isAtEnd()) break;
                }
                try self.addToken(.plain);
            }
        }
    }

    fn wrap(self: *Lexer, kind: TokenType, closing: u8) !void {
        while (self.peek() != closing) {
            _ = self.advance();
            if (self.isAtEnd()) {
                try self.addToken(.plain);
                return;
            }
        }

        _ = self.advance(); // Advance on closing
        try self.addToken(kind);
    }

    fn identifier(self: *Lexer) bool {
        const chr = self.peek();
        if (std.mem.indexOf(u8, &delimiters, &[1]u8 { chr }) != null) return true;
        return false;
    }

    fn peek(self: *Lexer) u8 {
        assert(self.current < self.raw.len);
        return self.raw[self.current];
    }

    fn peekAhead(self: *Lexer, n: usize) u8 {
        assert(self.current + n < self.raw.len);
        return self.raw[self.current + n];
    }

    fn advance(self: *Lexer) u8 {
        assert(self.current < self.raw.len);
        const chr = self.peek();
        self.current += 1;
        self.col += 1;
        return chr;
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.current >= self.raw.len;
    }
};

const ParserError = error{ UnexpectedToken } || error{ OutOfMemory };

const Self = @This();

allocator: Allocator,
raw: []const u8,
frontmatter: StringHashMap,
tokens: *ArrayList(Token) = undefined,
ast: Element,
output: []const u8 = "",

start: usize,
current: usize,

temp_strings: ArrayList([]u8),

pub fn toHtml(allocator: Allocator, raw: []const u8) !Self {
    var self: Self = .{
        .allocator = allocator,
        .raw = raw,
        .frontmatter = StringHashMap.init(allocator),
        .ast = Element.init(allocator, "div"),

        .start = 0,
        .current = 0,

        .temp_strings = ArrayList([]u8).init(allocator)
    };

    var lexer = Lexer.init(allocator, raw);
    defer lexer.deinit();
    _ = try lexer.tokenize();
    self.tokens = &lexer.tokens;

    self.parseFrontmatter() catch |err| {
        std.debug.print("{any}\n", .{err});
        if (err == ParserError.UnexpectedToken) {
            // Frontmatter doesn't exist, parse it later.
            self.start = 0;
            self.current = 0;
            self.clearFrontmatter();
        }
    };
    try self.parse();

    try self.pluginPass();

    var html = ArrayList(u8).init(self.allocator);
    defer html.deinit();
    try self.ast.toHtml(&html);

    self.output = try self.allocator.dupe(u8, html.items);

    return self;
}

pub fn deinit(self: *Self) void {
    self.frontmatter.deinit();
    self.ast.deinit();
    self.allocator.free(self.output);
    for (self.temp_strings.items) |str| {
        self.allocator.free(str);
    }
    self.temp_strings.deinit();
}

fn fix(self: *Self) void {
    // Unexpected token, adopt as plain text.
    _ = self;
}

fn pluginPass(self: *Self) !void {
    var toc = plugins.TableOfContents.init(self.allocator);
    defer toc.deinit();

    try toc.operate(&self.ast);
}

fn clearFrontmatter(self: *Self) void {
    var it = self.frontmatter.keyIterator();
    while (it.next()) |key| {
        _ = self.frontmatter.remove(key.*);
    }
}

fn parseFrontmatter(self: *Self) ParserError!void {
    if (self.peek().kind == .frontmatter) {
        _ = self.advance();
        _ = try self.eat(.nl);
        while (!self.match(.frontmatter)) {
            if (self.isAtEnd())
                return ParserError.UnexpectedToken;

            const k_token = try self.eat(.plain);
            _ = try self.eat(.colon);
            const v_token = self.gather(.nl);

            const k = trim(self.raw[k_token.start..k_token.start + k_token.length]);
            const v = trim(self.raw[v_token.start..v_token.start + v_token.length]);

            try self.frontmatter.put(k, v);

            _ = try self.eat(.nl);
        }
        _ = try self.eat(.frontmatter);
        _ = try self.eat(.nl);
    }
}

fn parse(self: *Self) !void {
    self.start = self.current;
    // for (self.tokens.items[self.start..self.start + 5]) |token| {
    //     const val = self.raw[token.start..token.start + token.length];
    //     if (std.mem.eql(u8, val, "\n")) {
    //         std.debug.print("{any}\n", .{token});
    //     } else {
    //         std.debug.print("{any} {s}\n", .{token, val});
    //     }
    // }

    var max: usize = 0;
    while (!self.isAtEnd()) {
        self.skipNewlines();
        try self.parseBlock(&self.ast);
        max += 1;
        if (max == 21) return;
    }
}

fn parseBlock(self: *Self, parent: *Element) !void {
    const token = self.advance();
    switch (token.kind) {
        .blockquote => {
            var blockquote = Element.init(self.allocator, "blockquote");
            var p = Element.init(self.allocator, "p");
            try self.parseInline(&p);
            try blockquote.addChild(p);
            try parent.addChild(blockquote);
        },
        .heading => {
            try self.temp_strings.append(try std.fmt.allocPrint(self.allocator, "h{d}", .{token.length}));
            const tag = self.temp_strings.items[self.temp_strings.items.len - 1];
            var heading = Element.init(self.allocator, tag);
            try self.parseInline(&heading);
            try parent.addChild(heading);
        },
        .exclaim => {
            const alt = try self.eat(.bracket);
            const src = try self.eat(.paren);
            var img = Element.init(self.allocator, "img");
            try img.addProp(
                "alt",
                trim(self.raw[alt.start + 1..alt.start + alt.length - 1])
            );
            try img.addProp(
                "src",
                trim(self.raw[src.start + 1..src.start + src.length - 1])
            );
            try parent.addChild(img);
        },
        else => {
            var p = Element.init(self.allocator, "p");
            try p.addChild(
                try Element.textNode(
                    self.allocator,
                    self.raw[token.start..token.start + token.length]
                )
            );
            try self.parseInline(&p);
            try parent.addChild(p);
        }
    }
}

fn parseInline(self: *Self, parent: *Element) !void {
    var push = parent;
    while (!self.match(.nl)) {
        const token = self.advance();
        switch (token.kind) {
            .plain, .colon, .exclaim => {
                try push.addChild(
                    try Element.textNode(
                        self.allocator,
                        self.raw[token.start..token.start + token.length]
                    )
                );
            },
            .code => {
                var code = Element.init(self.allocator, "code");
                try code.addChild(
                    try Element.textNode(
                        self.allocator,
                        self.raw[token.start + 1..token.start + token.length - 1]
                    )
                );
                try push.addChild(code);
            },
            else => {
            }
        }
    }
}

fn skipNewlines(self: *Self) void {
    while (self.consume(.nl)) {}
}

fn gather(self: *Self, kind: TokenType) Token {
    var token = self.advance();
    while (!self.match(kind)) {
        const next = self.advance();
        token.length += next.length;
    }
    return token;
}

fn same(self: *Self, kind: TokenType) ParserError!Token {
    if (!self.match(kind))
        return ParserError.UnexpectedToken;
    var token = self.advance();
    while (self.match(kind)) {
        const next = self.advance();
        token.length += next.length;
    }
    return token;
}

fn advance(self: *Self) Token {
    assert(self.current + 1 < self.tokens.items.len);
    const token = self.tokens.items[self.current];
    self.current += 1;
    return token;
}

fn eat(self: *Self, kind: TokenType) ParserError!Token {
    assert(self.current < self.tokens.items.len);
    if (self.peek().kind == kind)
        return self.advance();
    return ParserError.UnexpectedToken;
}

fn peek(self: *Self) Token {
    assert(self.current < self.tokens.items.len);
    return self.tokens.items[self.current];
}

fn match(self: *Self, kind: TokenType) bool {
    if (self.peek().kind == kind)
        return true;
    return false;
}

fn consume(self: *Self, kind: TokenType) bool {
    if (self.peek().kind == kind) {
        _ = self.advance();
        return true;
    }
    return false;
}

fn isAtEnd(self: *Self) bool {
    return self.current >= self.tokens.items.len;
}