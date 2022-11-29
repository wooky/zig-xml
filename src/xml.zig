pub const c = @cImport(@cInclude("upnp/ixml.h"));
const std = @import("std");
const xml = @import("lib.zig");
const ArenaAllocator = std.heap.ArenaAllocator;

const logger = std.log.scoped(.@"xml");

fn AbstractNode(comptime NodeType: type) type {
    return struct {
        /// Get all child nodes.
        pub fn getChildNodes(self: *const NodeType) NodeList {
            return NodeList.init(c.ixmlNode_getChildNodes(handleToNode(self.handle)));
        }

        /// Get the first child of this node, if any. Useful if you expect this to be an element with a single text node.
        pub fn getFirstChild(self: *const NodeType) !?Node {
            if (c.ixmlNode_getFirstChild(handleToNode(self.handle))) |child_handle| {
                return try Node.fromHandle(child_handle);
            }
            return null;
        }

        /// Add a child to the end of this node.
        pub fn appendChild(self: *const NodeType, child: anytype) !void {
            try check(c.ixmlNode_appendChild(handleToNode(self.handle), handleToNode(child.handle)), "Failed to append child", "err");
        }

        /// Convert the node into a string.
        pub fn toString(self: *const NodeType) !DOMString {
            if (c.ixmlNodetoString(handleToNode(self.handle))) |string| {
                return DOMString.init(std.mem.sliceTo(string, 0));
            }
            logger.err("Failed to render node to string", .{});
            return xml.Error;
        }

        /// Convert to generic node.
        pub fn toNode(self: *const NodeType) !Node {
            return try Node.fromHandle(handleToNode(self.handle));
        }
    };
}

/// Generic XML node.
pub const Node = union(enum) {
    Document: Document,
    Element: Element,
    TextNode: TextNode,

    fn fromHandle(handle: *c.IXML_Node) !Node {
        return switch (c.ixmlNode_getNodeType(handle)) {
            c.eDOCUMENT_NODE => Node { .Document = Document.init(@ptrCast(*c.IXML_Document, handle)) },
            c.eELEMENT_NODE => Node { .Element = Element.init(@ptrCast(*c.IXML_Element, handle)) },
            c.eTEXT_NODE => Node { .TextNode = TextNode.init(handle) },
            else => |node_type| {
                logger.err("Unhandled XML node type {}", .{node_type});
                return xml.Error;
            }
        };
    }
};

/// XML document.
pub const Document = struct {
    pub usingnamespace AbstractNode(Document);

    handle: *c.IXML_Document,

    /// Create an empty document.
    pub fn new() !Document {
        var handle: [*c]c.IXML_Document = undefined;
        try check(c.ixmlDocument_createDocumentEx(&handle), "Failed to create document", "err");
        return Document.init(handle);
    }

    /// Parse document from sentinel-terminated string.
    pub fn fromString(doc: [:0]const u8) !Document {
        var handle: [*c]c.IXML_Document = undefined;
        try check(c.ixmlParseBufferEx(doc.ptr, &handle), "Cannot parse document from string", "warn");
        return Document.init(handle);
    }

    pub fn init(handle: *c.IXML_Document) Document {
        return Document { .handle = handle };
    }

    pub fn deinit(self: *const Document) void {
        c.ixmlDocument_free(self.handle);
    }

    /// Create a new element with the specified tag name, belonging to this document. Use `appendChild()` to insert it into another node.
    pub fn createElement(self: *const Document, tag_name: [:0]const u8) !Element {
        var element_handle: [*c]c.IXML_Element = undefined;
        try check(c.ixmlDocument_createElementEx(self.handle, tag_name.ptr, &element_handle), "Failed to create element", "err");
        return Element.init(element_handle);
    }

    /// Create a text node with the specified data, belonging to this document. Use `appendChild()` to insert it into another node.
    pub fn createTextNode(self: *const Document, data: [:0]const u8) !TextNode {
        var node_handle: [*c]c.IXML_Node = undefined;
        try check(c.ixmlDocument_createTextNodeEx(self.handle, data.ptr, &node_handle), "Failed to create text node", "err");
        return TextNode.init(node_handle);
    }

    /// Get all elements by tag name in this document.
    pub fn getElementsByTagName(self: *const Document, tag_name: [:0]const u8) NodeList {
        return NodeList.init(c.ixmlDocument_getElementsByTagName(self.handle, tag_name.ptr));
    }

    /// Convert the document into a string. Adds the XML prolog to the beginning.
    pub fn toStringWithProlog(self: *const Document) !DOMString {
        if (c.ixmlDocumenttoString(self.handle)) |string| {
            return DOMString.init(std.mem.sliceTo(string, 0));
        }
        logger.err("Failed to render document to string", .{});
        return xml.Error;
    }
};

/// XML element.
pub const Element = struct {
    pub usingnamespace AbstractNode(Element);

    handle: *c.IXML_Element,

    pub fn init(handle: *c.IXML_Element) Element {
        return Element { .handle = handle };
    }

    /// Get the tag name of this element.
    pub fn getTagName(self: *const Element) [:0]const u8 {
        return std.mem.sliceTo(c.ixmlElement_getTagName(self.handle), 0);
    }

    /// Get single attribute of this element, if it exists.
    pub fn getAttribute(self: *const Element, name: [:0]const u8) ?[:0]const u8 {
        if (c.ixmlElement_getAttribute(self.handle, name.ptr)) |attr| {
            return std.mem.sliceTo(attr, 0);
        }
        return null;
    }

    /// Set or replace an attribute of this element.
    pub fn setAttribute(self: *const Element, name: [:0]const u8, value: [:0]const u8) !void {
        try check(c.ixmlElement_setAttribute(self.handle, name.ptr, value.ptr), "Failed to set attribute", "err");
    }

    /// Remove an attributes from this element.
    pub fn removeAttribute(self: *const Element, name: [:0]const u8) !void {
        try check(c.ixmlElement_removeAttribute(self.handle, name), "Failed to remove attriute", "err");
    }

    /// Get all attributes of this element.
    pub fn getAttributes(self: *const Element) AttributeMap {
        return AttributeMap.init(c.ixmlNode_getAttributes(handleToNode(self.handle)));
    }

    /// Get all child elements with the specified tag name.
    pub fn getElementsByTagName(self: *const Element, tag_name: [:0]const u8) NodeList {
        return NodeList.init(c.ixmlElement_getElementsByTagName(self.handle, tag_name.ptr));
    }
};

/// XML text node, which only contains a string value.
pub const TextNode = struct {
    pub usingnamespace AbstractNode(TextNode);

    handle: *c.IXML_Node,

    pub fn init(handle: *c.IXML_Node) TextNode {
        return TextNode { .handle = handle };
    }

    /// Get the string value of this node.
    pub fn getValue(self: *const TextNode) [:0]const u8 {
        return std.mem.sliceTo(c.ixmlNode_getNodeValue(self.handle), 0);
    }

    /// Set the string value of this node.
    pub fn setValue(self: *const TextNode, value: [:0]const u8) !void {
        try check(c.ixmlNode_setNodeValue(self.handle, value), "Failed to set text node value", "err");
    }
};

/// List of generic nodes belonging to a parent node.
pub const NodeList = struct {
    handle: ?*c.IXML_NodeList,

    pub fn init(handle: ?*c.IXML_NodeList) NodeList {
        return NodeList { .handle = handle };
    }

    /// Count how many nodes are in this list.
    pub fn getLength(self: *const NodeList) usize {
        return if (self.handle) |h|
            c.ixmlNodeList_length(h)
        else
            0;
    }

    /// Get a node by index. Returns an error if the item doesn't exist.
    pub fn getItem(self: *const NodeList, index: usize) !Node {
        if (self.handle) |h| {
            if (c.ixmlNodeList_item(h, index)) |item_handle| {
                return try Node.fromHandle(item_handle);
            }
            logger.err("Cannot query node list item", .{});
            return xml.Error;
        }
        logger.err("Cannot query empty node list", .{});
        return xml.Error;
    }

    /// Asserts that this list has one item, then retrieves it.
    pub fn getSingleItem(self: *const NodeList) !Node {
        const length = self.getLength();
        if (length != 1) {
            logger.warn("Node list expected to have 1 item, actual {d}", .{length});
            return xml.Error;
        }
        return self.getItem(0);
    }

    /// Return a new iterator for this list.
    pub fn iterator(self: *const NodeList) Iterator {
        return Iterator.init(self);
    }

    /// Read-only node list iterator
    pub const Iterator = struct {
        node_list: *const NodeList,
        length: usize,
        idx: usize = 0,

        fn init(node_list: *const NodeList) Iterator {
            return Iterator {
                .node_list = node_list,
                .length = node_list.getLength(),
            };
        }

        /// Get the next item in the list, if any.
        pub fn next(self: *Iterator) !?Node {
            if (self.idx < self.length) {
                var node = try self.node_list.getItem(self.idx);
                self.idx += 1;
                return node;
            }
            return null;
        }
    };
};

/// Attributes for some XML element.
pub const AttributeMap = struct {
    handle: *c.IXML_NamedNodeMap,

    pub fn init(handle: *c.IXML_NamedNodeMap) AttributeMap {
        return AttributeMap { .handle = handle };
    }

    /// Get a text node for the corresponding attribute name, if it exists.
    pub fn getNamedItem(self: *const AttributeMap, name: [:0]const u8) ?TextNode {
        if (c.ixmlNamedNodeMap_getNamedItem(self.handle, name.ptr)) |child_handle| {
            return TextNode.init(child_handle);
        }
        return null;
    }
};

/// A specially allocated string. You must call `deinit()` when you're done with it.
pub const DOMString = struct {

    /// The actual string.
    string: [:0]const u8,

    pub fn init(string: [:0]const u8) DOMString {
        return DOMString { .string = string };
    }

    pub fn deinit(self: *DOMString) void {
        c.ixmlFreeDOMString(@intToPtr(*u8, @ptrToInt(self.string.ptr)));
    }
};

inline fn check(err: c_int, comptime message: []const u8, comptime severity: []const u8) !void {
    if (err != c.IXML_SUCCESS) {
        @field(logger, severity)(message ++ ": {d}", .{err}); // TODO convert err to a more useful string
        return error.XMLError;
    }
}

inline fn handleToNode(handle: anytype) *c.IXML_Node {
    return @ptrCast(*c.IXML_Node, handle);
}
