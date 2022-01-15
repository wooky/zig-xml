const std = @import("std");
const xml = @import("lib.zig");

const attributes_field_name = "__attributes__";
const item_field_name = "__item__";

pub fn StructTraverser(comptime Self: type) type {
    return struct {
        pub fn traverseStruct(self: *Self, input: anytype, parent: xml.Node) !void {
            inline for (@typeInfo(@TypeOf(input.*)).Struct.fields) |field| {
                try self.traverseField(&@field(input, field.name), field.name, parent);
            }
        }

        pub fn traverseField(self: *Self, input: anytype, comptime name: []const u8, parent: xml.Node) !void {
            switch (@typeInfo(@TypeOf(input.*))) {
                .Struct =>
                    if (comptime std.mem.eql(u8, name, attributes_field_name)) {
                        try self.handleAttributes(input, parent.Element);
                    }
                    else {
                        try self.handleSubStruct(name, input, parent);
                    }
                ,
                .Pointer => |p| {
                    if (@typeInfo(p.child) == .Struct) {
                        return self.handlePointer(name, input, parent.Element);
                    }
                    if (p.child == u8) {
                        return self.handleLeafNode(input, name, parent.Element, Self.handleString);
                    }
                    @compileError("Field " ++ name ++ " has unsupported pointer type " ++ @typeName(p.child));
                },
                .Optional => try self.handleOptional(name, input, parent.Element),
                .Int => try self.handleLeafNode(input, name, parent.Element, Self.handleInt),
                .Bool => try self.handleLeafNode(input, name, parent.Element, Self.handleBool),
                else => @compileError("Unsupported field " ++ name ++ " inside struct")
            }
        }

        pub fn handleLeafNode(self: *Self, input: anytype, comptime name: []const u8, parent: xml.Element, forwardFn: anytype) !void {
            if (comptime !std.mem.eql(u8, name, item_field_name)) {
                return self.handleSingleItem(name, input, parent);
            }
            return forwardFn(self, name, input, parent);
        }
    };
}
