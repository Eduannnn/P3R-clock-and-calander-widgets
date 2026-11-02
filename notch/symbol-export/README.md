# Local SF Symbols extraction

This Rust tool converts outlines from a user-provided SF Symbols OpenType font
into white SVG icons. The widget reads them from
`~/.local/share/icons/SFSymbols/scalable/status/`, respecting `XDG_DATA_HOME`.
The font, downloaded installer, and generated artwork stay outside Git.

Use a recent `7zz` with APFS/LZFSE support, `bsdtar`, Cargo, and Rust. On NixOS,
these tools are available with `nix-shell -p _7zz libarchive cargo rustc stdenv.cc`.

From the repository root:

```sh
extract_dir="${XDG_CACHE_HOME:-$HOME/.cache}/p3r-widgets/sf-symbols"
mkdir -p "$extract_dir/pkg" "$extract_dir/resources"
7zz x -y "-o$extract_dir" "$HOME/Downloads/SF-Symbols-27.dmg" SFSymbols.pkg
7zz x -y "-o$extract_dir/pkg" "$extract_dir/SFSymbols.pkg" 'SFSymbolsPackage.pkg/*'
bsdtar -xf "$extract_dir/pkg/SFSymbolsPackage.pkg/Payload" -C "$extract_dir/resources" \
  './Applications/SF Symbols.app/Contents/Resources/Fonts'
curl -fsSL https://raw.githubusercontent.com/qzrzz/SF-Symbols-JSON/main/src/sf-symbols.json \
  -o "$extract_dir/names.json"
cargo run --release --locked --manifest-path notch/symbol-export/Cargo.toml \
  --target-dir "${XDG_CACHE_HOME:-$HOME/.cache}/p3r-widgets/symbol-export-build" -- \
  "$extract_dir/resources/Applications/SF Symbols.app/Contents/Resources/Fonts/SFSymbolsFallback.otf" \
  "$extract_dir/names.json" "${XDG_DATA_HOME:-$HOME/.local/share}/icons/SFSymbols"
```

The [name-to-character map](https://github.com/qzrzz/SF-Symbols-JSON) supplies
public-name aliases; all outlines come from the local font. Its map currently
covers SF Symbols 7. Additional glyphs and size variants from newer fonts are
exported under their internal glyph names, such as `uni10xxxx.small.svg`.
`symbols.json` records every exported filename and its source glyph ID.

The exporter keeps glyph shapes intact and uses white fills for the black notch
background. Controller, headphones, earbuds, keyboard, mouse, phone, and speaker
icons are addressed by public symbol name. No macOS executable is run.
