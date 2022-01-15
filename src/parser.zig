const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const xml = @import("lib.zig");

const Parser = @This();
const logger = std.log.scoped(.@"zupnp.xml.Parser");
usingnamespace @import("traverser.zig").StructTraverser(Parser);

pub fn DecodeResult(comptime T: type) type {
    return struct {
        result: *T,
        arena: ArenaAllocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
        }
    };
}

arena: ArenaAllocator,

pub fn init(allocator: std.mem.Allocator) Parser {
    return .{ .arena = ArenaAllocator.init(allocator) };
}

pub fn cleanup(self: *Parser) void {
    self.arena.deinit();
}

pub fn parseDocument(self: *Parser, comptime T: type, doc: xml.Document) !DecodeResult(T) {
    var result = try self.arena.allocator().create(T);
    try self.traverseStruct(result, try doc.toNode());
    return DecodeResult(T) {
        .result = result,
        .arena = self.arena,
    };
}

pub fn handleSubStruct(self: *Parser, comptime name: []const u8, input: anytype, parent: xml.Node) !void {
    var child = switch (parent) {
        .Document => |d| d.getElementsByTagName(name ++ "\x00"),
        .Element => |e| e.getElementsByTagName(name ++ "\x00"),
        else => {
            logger.warn("Invalid type for node named {s}", .{name});
            return xml.Error;
        }
    }.getSingleItem() catch {
        logger.warn("Missing element {s}", .{name});
        return xml.Error;
    };
    try self.traverseStruct(input, child);
}

pub fn handlePointer(self: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    const PointerChild = @typeInfo(@TypeOf(input.*)).Pointer.child;
    var iterator = parent.getElementsByTagName(name ++ "\x00").iterator();
    if (iterator.length > 0) {
        var resultants = try self.arena.allocator().alloc(PointerChild, iterator.length);
        for (resultants) |*res| {
            try self.traverseField(res, name, (try iterator.next()).?);
        }
        input.* = resultants;
    }
    else {
        input.* = &[_]PointerChild {};
    }
}

pub fn handleOptional(self: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    const list = parent.getElementsByTagName(name ++ "\x00");
    switch (list.getLength()) {
        1 => {
            var subopt: @typeInfo(@TypeOf(input.*)).Optional.child = undefined;
            try self.traverseField(&subopt, name, try list.getSingleItem());
            input.* = subopt;
        },
        0 => input.* = null,
        else => |l| {
            logger.warn("Expecting 0 or 1 {s} elements, found {d}", .{name, l});
            return xml.Error;
        }
    }
}

pub fn handleString(self: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    var text_node = (try parent.getFirstChild()) orelse {
        // TODO text element might be present, but empty
        // logger.warn("Text element {s} has no text", .{name});
        // return xml.Error;
        input.* = "";
        return;
    };
    switch (text_node) {
        .TextNode => |tn| input.* = try self.arena.allocator().dupe(u8, tn.getValue()),
        else => {
            logger.warn("Element {s} is not a text element", .{name});
            return xml.Error;
        }
    }
}

pub fn handleInt(_: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    input.* = try std.fmt.parseInt(@TypeOf(input.*), try getTextNode(name, parent), 0);
}

pub fn handleBool(_: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    const maybe_bool = try getTextNode(name, parent);
    var actual_bool: bool = undefined;
    if (std.ascii.eqlIgnoreCase(maybe_bool, "true") or std.mem.eql(u8, maybe_bool, "1")) {
        actual_bool = true;
    }
    else if (std.ascii.eqlIgnoreCase(maybe_bool, "false") or std.mem.eql(u8, maybe_bool, "0")) {
        actual_bool = false;
    }
    else {
        logger.warn("Element {s} is not a valid bool", .{name});
        return xml.Error;
    }
    input.* = actual_bool;
}

pub fn handleAttributes(self: *Parser, input: anytype, parent: xml.Element) !void {
    var attributes = parent.getAttributes();
    inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
        const value = blk: {
            var node = attributes.getNamedItem(field.name ++ "\x00") orelse break :blk null;
            break :blk try self.arena.allocator().dupe(u8, node.getValue());
        };
        @field(input, field.name) = switch (field.field_type) {
            ?[]const u8, ?[]u8 => value,
            []const u8, []u8 => value orelse return xml.Error,
            else => @compileError("Invalid field '" ++ field.name ++ "' for attribute struct")
        };
    }
}

pub fn handleSingleItem(self: *Parser, comptime name: []const u8, input: anytype, parent: xml.Element) !void {
    var element = parent.getElementsByTagName(name ++ "\x00").getSingleItem() catch {
        logger.warn("Missing element {s}", .{name});
        return xml.Error;
    };
    try self.traverseField(input, "__item__", element);
}

fn getTextNode(comptime name: []const u8, parent: xml.Element) ![:0]const u8 {
    var text_node = (try parent.getFirstChild()) orelse {
        logger.warn("Text element {s} has no text", .{name});
        return xml.Error;
    };
    switch (text_node) {
        .TextNode => |tn| return tn.getValue(),
        else => {
            logger.warn("Element {s} is not a text element", .{name});
            return xml.Error;
        }
    }
}
