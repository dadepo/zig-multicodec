const std = @import("std");
const table = @import("table.zig");
const muvarint = @import("muvarint");

pub fn addNamePrefix(allocator: std.mem.Allocator, name: table.MultiCodeName, data: []u8) ![]u8 {
    const multicodec = table.multicodecTable.get(@tagName(name)) orelse return error.InvalidCodecName;
    if (multicodec.status != table.Status.Permanent) {
        return error.CodecNotPermanent;
    }
    var varint = try std.BoundedArray(u8, 128).init(muvarint.varintSize(multicodec.code));
    try muvarint.bufferEncode(multicodec.code, varint.slice());
    return try std.mem.concat(allocator, u8, &[_][]const u8{ varint.slice(), data });
}

pub fn getCodec(data: []u8) !?table.Multicodec {
    const decoded = try muvarint.decode(data[0..]);
    const codecs = table.multicodecTable.values();
    // improve with a look up.
    const codec: ?table.Multicodec = blk: {
        for (codecs) |codec| {
            if (codec.code == decoded.code) {
                break :blk codec;
            }
        }
        return null;
    };
    return codec;
}

test "addNamePrefix" {
    var input: [5]u8 = [_]u8{ 104, 101, 108, 108, 111 };
    const value = try addNamePrefix(std.testing.allocator, table.MultiCodeName.raw, input[0..]);
    defer std.testing.allocator.free(value);
    try std.testing.expect(std.mem.eql(u8, value, &[6]u8{ 85, 104, 101, 108, 108, 111 }));
}

test "getCodec" {
    var input: [5]u8 = [_]u8{ 104, 101, 108, 108, 111 };
    const prefixed = try addNamePrefix(std.testing.allocator, table.MultiCodeName.raw, input[0..]);
    defer std.testing.allocator.free(prefixed);
    const codec = try getCodec(prefixed);
    try std.testing.expectEqual(codec.?.code, @intFromEnum(table.MultiCodeCode.raw));
}
