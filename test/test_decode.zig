const testing = @import("std").testing;
const xml = @import("xml");
const full = @import("full.zig");

test "full structure" {
    var doc = try xml.Document.fromString(full.file);
    defer doc.deinit();
    var decode_result = try xml.decode(testing.allocator, full.TestStructure, doc);
    defer decode_result.deinit();
    const result = decode_result.result;

    try testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    try testing.expectEqualStrings("world", result.root.element1.__attributes__.attr2.?);
    try testing.expectEqualStrings("I am required", result.root.element1.child1);
    try testing.expectEqual(@as(i16, -23), result.root.element1.@"int-child".?);
    try testing.expectEqual(true, result.root.element1.@"wacky:child".?);
    try testing.expectEqualStrings("I am optional", result.root.element2.child2.?);
    try testing.expectEqual(@as(usize, 2), result.root.element2.repeated.len);
    try testing.expectEqualStrings("Another one", result.root.element2.repeated[0].anotherone.__item__);
    try testing.expectEqualStrings("Another two", result.root.element2.repeated[1].anotherone.__item__);
    try testing.expectEqualStrings("yes", result.root.element2.repeated[1].anotherone.__attributes__.optionalattr.?);
}

test "minimal structure" {
    var doc = try xml.Document.fromString(
        \\<?xml version=\"1.0\"?>
        \\<root>
        \\  <element1 attr1="hello">
        \\      <child1>I am required</child1>
        \\  </element1>
        \\  <element2>
        \\  </element2>
        \\</root>
    );
    defer doc.deinit();
    var decode_result = try xml.decode(testing.allocator, full.TestStructure, doc);
    defer decode_result.deinit();
    const result = decode_result.result;

    try testing.expectEqualStrings("hello", result.root.element1.__attributes__.attr1);
    try testing.expectEqual(@as(?[]const u8, null), result.root.element1.__attributes__.attr2);
    try testing.expectEqualStrings("I am required", result.root.element1.child1);
    try testing.expectEqual(@as(?[]const u8, null), result.root.element2.child2);
    try testing.expectEqual(@as(usize, 0), result.root.element2.repeated.len);
}

test "empty document" {
    var doc = try xml.Document.fromString("<?xml version=\"1.0\"?>");
    defer doc.deinit();
    try testing.expectError(xml.Error, xml.decode(testing.allocator, full.TestStructure, doc));
}
