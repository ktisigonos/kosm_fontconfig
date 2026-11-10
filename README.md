# kosm_fontconfig

Fontconfig for kosm: the fonts the generic families `sans-serif`, `serif` and `monospace`
resolve to, each a list in fallback order. Every program asking fontconfig for a generic
family (kitty, GTK and Qt apps, browsers showing pages in your fonts) then gets the kosmos'
fonts.

The app writes one file whole, `~/.config/fontconfig/conf.d/50-kosm.conf`, which fontconfig
reads through the system's `50-user.conf`. Your own `fonts.conf` stays yours; fontconfig
reads `conf.d` first, so the kosmos' fonts come before any family `fonts.conf` also prefers.

```zig
var fonts = kosm_fontconfig.from(theme);
fonts.monospace = &.{ "Maple Mono Normal NFP", "Noto Color Emoji" };
```

## Fields

| Field | Default |
|---|---|
| `file` | `~/.config/fontconfig/conf.d/50-kosm.conf`; its name must start with a digit and end in `.conf` |
| `sans_serif` | null: not written, fontconfig's own |
| `serif` | null: not written, fontconfig's own |
| `monospace` | null: not written, fontconfig's own |
| `binding` | `.strong`: the listed fonts win over the system's family rules and language matching. `.weak` is fontconfig's default, under which a distribution's rules (Noto's, for one) can pass over a listed font |

`from` sets nothing, since the theme holds no fonts.

After an apply, programs already running may keep the old fonts until restarted.
