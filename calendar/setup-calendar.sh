#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
state_dir="${XDG_DATA_HOME:-$HOME/.local/share}/p3r-widgets"
config_file="${XDG_CONFIG_HOME:-$HOME/.config}/p3r-widgets/calendar.json"
export P3R_CALENDAR_MANIFEST="$source_dir/calendar-sync/Cargo.toml"
export P3R_CALENDAR_TARGET="${XDG_CACHE_HOME:-$HOME/.cache}/p3r-widgets/calendar-build"

case "${1:-}" in
    ""|--configure|--build-only) ;;
    *) printf 'Usage: %s [--configure|--build-only]\n' "$0" >&2; exit 1 ;;
esac

# Compile once; the running widgets only need the resulting native executable.
if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
    cargo build --release --locked --manifest-path "$P3R_CALENDAR_MANIFEST" --target-dir "$P3R_CALENDAR_TARGET"
elif command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p cargo rustc stdenv.cc --run \
        'cargo build --release --locked --manifest-path "$P3R_CALENDAR_MANIFEST" --target-dir "$P3R_CALENDAR_TARGET"'
else
    printf 'Install Rust (cargo and rustc) and a C compiler, then run this script again.\n' >&2
    exit 1
fi

mkdir -p -- "$state_dir/bin"
calendar_helper="$state_dir/bin/p3r-calendar-sync"
# Rename into place so a currently running sync can finish using the old executable.
install -m 755 "$P3R_CALENDAR_TARGET/release/p3r-calendar-sync" "$calendar_helper.new"
mv -f -- "$calendar_helper.new" "$calendar_helper"

if [[ "${1:-}" == --build-only ]]; then
    printf 'Installed calendar helper: %s\n' "$calendar_helper"
elif [[ -f "$config_file" && "${1:-}" != --configure ]]; then
    exec "$calendar_helper" migrate
else
    exec "$calendar_helper" configure
fi
