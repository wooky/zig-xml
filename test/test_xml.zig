const testing = @import("std").testing;
const Document = @import("xml").Document;
const full = @import("full.zig");

test "encoding to XML" {
    var doc = try Document.new();
    defer doc.deinit();

    var root = try doc.createElement("root");
    try doc.appendChild(root);

    {
        var element1 = try doc.createElement("element1");
        try root.appendChild(element1);
        try element1.setAttribute("attr1", "hello");
        try element1.setAttribute("attr2", "world");

        {
            var child1 = try doc.createElement("child1");
            try element1.appendChild(child1);

            var child1_text = try doc.createTextNode("I am required");
            try child1.appendChild(child1_text);
        }

        {
            var int_child = try doc.createElement("int-child");
            try element1.appendChild(int_child);

            var int_child_text = try doc.createTextNode("-23");
            try int_child.appendChild(int_child_text);
        }

        {
            var wacky_child = try doc.createElement("wacky:child");
            try element1.appendChild(wacky_child);

            var wacky_child_text = try doc.createTextNode("1");
            try wacky_child.appendChild(wacky_child_text);
        }
    }

    {
        var element2 = try doc.createElement("element2");
        try root.appendChild(element2);

        {
            var child2 = try doc.createElement("child2");
            try element2.appendChild(child2);

            var child2_text = try doc.createTextNode("I am optional");
            try child2.appendChild(child2_text);
        }

        {
            var repeated = try doc.createElement("repeated");
            try element2.appendChild(repeated);

            var anotherone = try doc.createElement("anotherone");
            try repeated.appendChild(anotherone);

            var anotherone_text = try doc.createTextNode("Another one");
            try anotherone.appendChild(anotherone_text);
        }

        {
            var repeated = try doc.createElement("repeated");
            try element2.appendChild(repeated);

            var anotherone = try doc.createElement("anotherone");
            try repeated.appendChild(anotherone);
            try anotherone.setAttribute("optionalattr", "yes");

            var anotherone_text = try doc.createTextNode("Another two");
            try anotherone.appendChild(anotherone_text);
        }
    }

    var string = try doc.toStringWithProlog();
    defer string.deinit();
    try testing.expectEqualStrings(full.file, string.string);
}

test "decoding from XML" {
    var doc = try Document.fromString(full.file);
    defer doc.deinit();

    const root = (try doc.getElementsByTagName("root").getSingleItem()).Element;

    const element1 = (try root.getElementsByTagName("element1").getSingleItem()).Element;
    try testing.expectEqualStrings("hello", element1.getAttribute("attr1").?);
    try testing.expectEqualStrings("world", element1.getAttribute("attr2").?);
    try testing.expect(element1.getAttribute("bogus") == null);

    const child1 = (try element1.getElementsByTagName("child1").getSingleItem()).Element;
    const child1_text = (try child1.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("I am required", child1_text.getValue());

    const int_child = (try element1.getElementsByTagName("int-child").getSingleItem()).Element;
    const int_child_text = (try int_child.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("-23", int_child_text.getValue());

    const wacky_child = (try element1.getElementsByTagName("wacky:child").getSingleItem()).Element;
    const wacky_child_text = (try wacky_child.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("1", wacky_child_text.getValue());

    const bogus_children = element1.getElementsByTagName("bogus");
    try testing.expectEqual(@as(usize, 0), bogus_children.getLength());

    const element2 = (try root.getElementsByTagName("element2").getSingleItem()).Element;

    const child2 = (try element2.getElementsByTagName("child2").getSingleItem()).Element;
    const child2_text = (try child2.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("I am optional", child2_text.getValue());

    var repeated_iter = element2.getElementsByTagName("repeated").iterator();

    const repeated1 = (try repeated_iter.next()).?.Element;
    const anotherone1 = (try repeated1.getElementsByTagName("anotherone").getSingleItem()).Element;
    const anotherone1_text = (try anotherone1.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("Another one", anotherone1_text.getValue());

    const repeated2 = (try repeated_iter.next()).?.Element;
    const anotherone2 = (try repeated2.getElementsByTagName("anotherone").getSingleItem()).Element;
    const anotherone2_text = (try anotherone2.getFirstChild()).?.TextNode;
    try testing.expectEqualStrings("Another two", anotherone2_text.getValue());
    try testing.expectEqualStrings("yes", anotherone2.getAttribute("optionalattr").?);

    try testing.expect((try repeated_iter.next()) == null);
}
