pub const file = @embedFile("full.xml");

pub const Repeated = struct {
    anotherone: struct {
        __attributes__: struct {
            optionalattr: ?[]const u8 = null,
        } = .{},
        __item__: []const u8
    }
};
pub const TestStructure = struct {
    root: struct {
        element1: struct {
            __attributes__: struct {
                attr1: []const u8,
                attr2: ?[]const u8,
            },
            child1: []const u8,
            @"int-child": ?i16,
            @"wacky:child": ?bool,
        },
        element2: struct {
            child2: ?[]const u8,
            repeated: []const Repeated,
        },
    },
};
