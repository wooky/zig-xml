const testing = @import("std").testing;
const xml = @import("xml");
const full = @import("full.zig");

test "full structure" {
    const input = full.TestStructure {
        .root = .{
            .element1 = .{
                .__attributes__ = .{
                    .attr1 = "hello",
                    .attr2 = "world",
                },
                .child1 = "I am required",
                .@"int-child" = -23,
                .@"wacky:child" = true,
            },
            .element2 = .{
                .child2 = "I am optional",
                .repeated = &[_] full.Repeated {
                    .{
                        .anotherone = .{
                            .__item__ = "Another one"
                        },
                    },
                    .{
                        .anotherone = .{
                            .__attributes__ = .{
                                .optionalattr = "yes",
                            },
                            .__item__ = "Another two",
                        },
                    },
                },
            },
        },
    };
    var doc = try xml.encode(testing.allocator, input);
    defer doc.deinit();
    var result = try doc.toStringWithProlog();
    defer result.deinit();

    try testing.expectEqualStrings(full.file, result.string);
}
