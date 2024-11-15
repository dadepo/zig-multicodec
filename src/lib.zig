const std = @import("std");
const table = @import("table.zig");
const muvarint = @import("muvarint");

pub fn addNamePrefix(allocator: std.mem.Allocator, name: table.MultiCodeName, data: []u8) ![]u8 {
    const multicodec = table.multicodecTable.get(@tagName(name)) orelse return error.InvalidCodecName;
    if (multicodec.status != table.Status.Permanent) {
        return error.CodecNotPermanent;
    }
    const varint = try muvarint.encodeHexAlloc(allocator, multicodec.code);
    defer allocator.free(varint);
    return try std.mem.concat(allocator, u8, &[_][]const u8{ varint, data });
}

test "addNamePrefix" {
    var input: [5]u8 = [_]u8{ 104, 101, 108, 108, 111 };
    const value = try addNamePrefix(std.testing.allocator, table.MultiCodeName.raw, input[0..]);
    defer std.testing.allocator.free(value);
    try std.testing.expect(std.mem.eql(u8, value, &[6]u8{ 85, 104, 101, 108, 108, 111 }));
}
