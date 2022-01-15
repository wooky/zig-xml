//! XML library.
//! Comes in two flavours: the traditional `Document` system, or the Zig-specific `encode` and `decode`, allowing you to convert XML to and from structs.

const xml = @import("xml.zig");
pub usingnamespace xml;
pub const DecodeResult = @import("parser.zig").DecodeResult;
pub const Error = error.XMLError;

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Encode a struct to a XML document. Caller owns the document and should call `deinit()` on it when done.
pub fn encode(allocator: Allocator, input: anytype) !xml.Document {
    var writer = @import("writer.zig").init(allocator);
    defer writer.deinit();
    return writer.writeStructToDocument(input);
}

/// Decode an XML document to a struct. Resulting struct gets allocated on the heap; call `deinit()` on the result object when you're done with it.
pub fn decode(allocator: Allocator, comptime T: type, doc: xml.Document) !DecodeResult(T) {
    var parser = @import("parser.zig").init(allocator);
    errdefer parser.cleanup();
    return parser.parseDocument(T, doc);
}
