#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
export P3R_WINDOW_STATE_MANIFEST="$source_dir/window-state/Cargo.toml"
export P3R_WINDOW_STATE_TARGET="${XDG_CACHE_HOME:-$HOME/.cache}/p3r-widgets/window-state-build"
if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
    cargo build --release --locked --manifest-path "$P3R_WINDOW_STATE_MANIFEST" --target-dir "$P3R_WINDOW_STATE_TARGET"
elif command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p cargo rustc stdenv.cc --run \
        'cargo build --release --locked --manifest-path "$P3R_WINDOW_STATE_MANIFEST" --target-dir "$P3R_WINDOW_STATE_TARGET"'
else
    printf 'Install Rust and a C compiler to enable window-state tracking on KDE.\n' >&2
    exit 1
fi
helper_dir="${XDG_DATA_HOME:-$HOME/.local/share}/p3r-widgets/bin"
mkdir -p -- "$helper_dir"
install -m 755 "$P3R_WINDOW_STATE_TARGET/release/p3r-clock-window-state" "$helper_dir/p3r-clock-window-state.new"
mv -- "$helper_dir/p3r-clock-window-state.new" "$helper_dir/p3r-clock-window-state"
printf 'Installed KDE window-state monitor. Restart widgets after installing.\n'
