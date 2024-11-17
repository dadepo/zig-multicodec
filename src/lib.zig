const std = @import("std");
const table = @import("table.zig");
const muvarint = @import("muvarint");

pub fn getCodecByName(name: table.MultiCodeName) !table.Multicodec {
    return table.multicodecTable.get(@tagName(name)) orelse return error.InvalidCodecName;
}

pub fn addNamePrefix(allocator: std.mem.Allocator, name: table.MultiCodeName, data: []u8) ![]u8 {
    const multicodec = try getCodecByName(name);
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

pub fn getData(data: []u8) ![]const u8 {
    const decoded = try muvarint.decode(data[0..]);
    return decoded.rest;
}

pub fn split(data: []u8) !?struct { codec: table.Multicodec, data: []const u8 } {
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

    return .{ .codec = codec.?, .data = decoded.rest };
}

test "getCodecByName" {
    {
        const codec = try getCodecByName(table.MultiCodeName.raw);
        try std.testing.expect(std.mem.eql(u8, codec.name, "raw"));
    }
    {
        const codec = try getCodecByName(table.MultiCodeName.lamport_sha3_512_priv_share);
        try std.testing.expect(std.mem.eql(u8, codec.name, "lamport-sha3-512-priv-share"));
    }
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

test "getData" {
    var input: [5]u8 = [_]u8{ 104, 101, 108, 108, 111 };
    const prefixed = try addNamePrefix(std.testing.allocator, table.MultiCodeName.raw, input[0..]);
    defer std.testing.allocator.free(prefixed);
    const data = try getData(prefixed);
    try std.testing.expect(std.mem.eql(u8, data, &[5]u8{ 104, 101, 108, 108, 111 }));
}

test "split" {
    var input: [5]u8 = [_]u8{ 104, 101, 108, 108, 111 };
    const prefixed = try addNamePrefix(std.testing.allocator, table.MultiCodeName.raw, input[0..]);
    defer std.testing.allocator.free(prefixed);
    const codec_and_data = try split(prefixed);
    try std.testing.expect(std.mem.eql(u8, prefixed, &[6]u8{ 85, 104, 101, 108, 108, 111 }));
    try std.testing.expectEqual(codec_and_data.?.codec.code, @intFromEnum(table.MultiCodeCode.raw));
    try std.testing.expect(std.mem.eql(u8, codec_and_data.?.data, &[5]u8{ 104, 101, 108, 108, 111 }));
}
