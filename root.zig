//! Fontconfig: the fonts the generic families `sans-serif`, `serif` and `monospace` resolve to.

const std = @import("std");

/// Fontconfig's generic families; build one with `from`.
pub const App = @import("App.zig");
/// An app with no family set; the theme holds no fonts.
pub const from = App.from;
/// The adapter the app writes its file with, so a config needs only this package.
pub const xml_adapter = @import("kosm_xml").adapter;

test {
    std.testing.refAllDecls(@This());
    std.testing.refAllDecls(App);
}
