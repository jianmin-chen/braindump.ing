const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Self = @This();

allocator: Allocator,
timestamp: i64,
year: usize = 0,
month: usize = 0,
day: usize = 0,
hour: usize = 0,
minute: usize = 0,
second: usize = 0,
millisecond: usize = 0,

leap_year: bool = false,

pub fn fromTimestamp(allocator: Allocator, timestamp: i64) !Self {
    var self: Self = .{
        .allocator = allocator,
        .timestamp = timestamp
    };
    try self.parse();
    return self;
}

fn daysInMonth(self: *Self, month: usize) usize {
    std.debug.assert(month >= 1 and month <= 12);
    const days = switch (month) {
        1 => return 31,
        2 => if (self.leap_year) return 29 else 28,
        3 => return 31,
        4 => return 30,
        5 => return 31,
        6 => return 30,
        7 => return 31,
        8 => return 31,
        9 => return 30,
        10 => return 31,
        11 => return 30,
        12 => return 31,
        else => unreachable
    };
    return days;
}

fn parse(self: *Self) !void {
    const timestamp: f64 = @floatFromInt(self.timestamp);

    const years: f64 = std.math.floor(timestamp / 60.0 / 60.0 / 24.0 / 365.0);
    self.year = @intFromFloat(years + 1970);
    if (self.year % 4 == 0) {
        if (self.year % 100 != 0 or self.year % 400 != 0)
            self.leap_year = true;
    }

    const days: f64 = (timestamp / 60.0 / 60.0 / 24.0) - (365.25 * years);
    self.day = @intFromFloat(days);

    var month: usize = 1;
    while (self.day > self.daysInMonth(month)) {
        self.day -= self.daysInMonth(month);
        month += 1;
    }
    self.month = month;
}

pub fn toString(self: *Self) ![]const u8 {
    var repr = ArrayList(u8).init(self.allocator);
    var writer = repr.writer();
    try writer.print("{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z", .{
        self.year,
        self.month,
        self.day,
        self.hour,
        self.minute,
        self.second,
        self.millisecond
    });
    return repr.toOwnedSlice();
}
