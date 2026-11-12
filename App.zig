//! Fontconfig's generic families: the fonts `sans-serif`, `serif` and `monospace` resolve to,
//! in fallback order, so every program asking fontconfig for them gets the kosmos' fonts.
//! The app owns one file in the user's `conf.d`, leaving `fonts.conf` to the user.

const App = @This();

const std = @import("std");
const kosm = @import("kosm");

/// The file the app writes whole. Fontconfig reads only `conf.d` files whose names start with
/// a digit and end in `.conf`, in name order. Default: `~/.config/fontconfig/conf.d/50-kosm.conf`.
file: []const u8 = "~/.config/fontconfig/conf.d/50-kosm.conf",
/// Fonts `sans-serif` resolves to, the first preferred and the rest its fallbacks:
/// `&.{ "Inter", "Noto Sans CJK JP", "Noto Color Emoji" }`. null: not written, fontconfig's own.
sans_serif: ?[]const []const u8 = null,
/// Fonts `serif` resolves to, in fallback order. null: not written, fontconfig's own.
serif: ?[]const []const u8 = null,
/// Fonts `monospace` resolves to, in fallback order. null: not written, fontconfig's own.
monospace: ?[]const []const u8 = null,
/// How strongly the listed fonts bind. `.strong` puts them ahead of the system's own family
/// rules and of language matching; `.weak` (fontconfig's default) lets those win, so a listed
/// font may be passed over for one the distribution prefers. Default: `.strong`.
binding: Binding = .strong,

/// Fontconfig's alias bindings.
pub const Binding = enum { weak, strong, same };

/// The theme holds no fonts, so every family is left null for the kosmos to set.
pub fn from(theme: kosm.Theme) App {
    _ = theme;
    return .{};
}

/// One `<alias>`: a generic family and the fonts it prefers.
const Alias = struct {
    @"@binding": Binding,
    family: []const u8,
    prefer: struct { family: []const []const u8 },
};

/// Writes `file` whole: one alias per family that is set, in the order sans-serif, serif,
/// monospace. With every family null the file holds no alias, so it changes nothing.
pub fn apply(self: App, output: *kosm.Output) !void {
    var aliases: std.ArrayList(Alias) = .empty;
    const families = [_]struct { []const u8, ?[]const []const u8 }{
        .{ "sans-serif", self.sans_serif },
        .{ "serif", self.serif },
        .{ "monospace", self.monospace },
    };
    for (families) |family| {
        const fonts = family[1] orelse continue;
        if (fonts.len == 0) return output.fail(self.file, "family '{s}' lists no fonts; leave it null to keep fontconfig's own", .{family[0]});
        try aliases.append(output.allocator, .{ .@"@binding" = self.binding, .family = family[0], .prefer = .{ .family = fonts } });
    }
    try output.generate(.{ .file = self.file, .lang = "xml" }, .{
        .@"!DOCTYPE" = kosm.raw("fontconfig SYSTEM \"urn:fontconfig:fonts.dtd\""),
        .fontconfig = .{ .alias = aliases.items },
    });
}

const testing = std.testing;
const xml = @import("kosm_xml");

const Fixture = struct {
    tmp: testing.TmpDir,
    arena: std.heap.ArenaAllocator,
    plan: kosm.Plan,
    diagnostics: kosm.Diagnostics = .{},
    warnings: kosm.Warnings = undefined,
    home_buffer: [std.Io.Dir.max_path_bytes]u8 = undefined,
    output: kosm.Output = undefined,

    fn init(fixture: *Fixture) !void {
        fixture.* = .{ .tmp = testing.tmpDir(.{}), .arena = .init(testing.allocator), .plan = .init(testing.allocator, testing.io) };
        fixture.warnings = .init(fixture.arena.allocator());
        const length = try fixture.tmp.dir.realPath(testing.io, &fixture.home_buffer);
        fixture.output = .{
            .allocator = fixture.arena.allocator(),
            .home = fixture.home_buffer[0..length],
            .adapters = &.{xml.adapter},
            .plan = &fixture.plan,
            .diagnostics = &fixture.diagnostics,
            .warnings = &fixture.warnings,
            .app = "fontconfig",
        };
    }

    fn deinit(fixture: *Fixture) void {
        fixture.plan.deinit();
        fixture.arena.deinit();
        fixture.tmp.cleanup();
    }

    fn planned(fixture: *Fixture, display_path: []const u8) []const u8 {
        for (fixture.plan.files.items) |file| {
            if (std.mem.eql(u8, file.display_path, display_path)) return file.new;
        }
        return "(not planned)";
    }
};

test "each family set prefers its fonts in fallback order, and a null family is not written" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const app: App = .{
        .sans_serif = &.{ "Inter", "Noto Color Emoji" },
        .monospace = &.{ "Maple Mono Normal NFP", "Symbols & Signs", "Noto Color Emoji" },
    };
    try app.apply(&fixture.output);
    try testing.expectEqualStrings(
        \\<?xml version="1.0"?>
        \\<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        \\<fontconfig>
        \\  <alias binding="strong">
        \\    <family>sans-serif</family>
        \\    <prefer>
        \\      <family>Inter</family>
        \\      <family>Noto Color Emoji</family>
        \\    </prefer>
        \\  </alias>
        \\  <alias binding="strong">
        \\    <family>monospace</family>
        \\    <prefer>
        \\      <family>Maple Mono Normal NFP</family>
        \\      <family>Symbols &amp; Signs</family>
        \\      <family>Noto Color Emoji</family>
        \\    </prefer>
        \\  </alias>
        \\</fontconfig>
        \\
    , fixture.planned("~/.config/fontconfig/conf.d/50-kosm.conf"));
}

test "with every family null the file holds no alias" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    try from(kosm.Theme.from(.{ .palette = .{ .black = kosm.hex("000000"), .white = kosm.hex("ffffff") }, .mode = .dark })).apply(&fixture.output);
    try testing.expectEqualStrings(
        \\<?xml version="1.0"?>
        \\<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        \\<fontconfig>
        \\</fontconfig>
        \\
    , fixture.planned("~/.config/fontconfig/conf.d/50-kosm.conf"));
}

test "a family listing no fonts fails naming it" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const app: App = .{ .serif = &.{} };
    try testing.expectError(error.AppFailed, app.apply(&fixture.output));
    try testing.expectEqualStrings("family 'serif' lists no fonts; leave it null to keep fontconfig's own", fixture.diagnostics.message());
    try testing.expectEqualStrings("~/.config/fontconfig/conf.d/50-kosm.conf", fixture.diagnostics.file);
    try testing.expect(!fixture.plan.hasChanges());
}
