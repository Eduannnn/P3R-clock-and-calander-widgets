#!/usr/bin/env bash
set -euo pipefail

# Install a private copy of the widgets and register a systemd user service.
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
install_dir="$HOME/.config/quickshell/p3r"
service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
service_name="p3r-widgets.service"

if (( EUID == 0 )); then
    printf 'Run this installer as your normal desktop user, without sudo.\n' >&2
    exit 1
fi

for dependency in quickshell cava systemctl tar; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'Missing dependency: %s. Install it and run this script again.\n' "$dependency" >&2
        exit 1
    fi
done

# Fail before copying files if the current session has no user service manager.
if ! systemctl --user show-environment >/dev/null; then
    printf 'Cannot connect to systemd for this user. Run from your desktop session.\n' >&2
    exit 1
fi

quickshell_bin=$(command -v quickshell)
if [[ "$quickshell_bin" != /* ]]; then
    printf 'Quickshell must resolve to an absolute executable path.\n' >&2
    exit 1
fi

# Plasma needs its native layout events for maximized and split-screen windows.
case "${XDG_CURRENT_DESKTOP:-}" in
    *KDE*|*kde*) "$source_dir/p3r-clock/setup-window-state.sh" ;;
esac

# Unit-file strings need escaped quotes, backslashes, and literal percent signs.
quote_unit_value() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//%/%%}
    printf '"%s"' "$value"
}

mkdir -p -- "$install_dir" "$service_dir"
if [[ "$source_dir" != "$(cd -- "$install_dir" && pwd -P)" ]]; then
    # Preserve relative entry-point symlinks; omit Git and local agent metadata.
    tar -C "$source_dir" \
        --exclude='./.git' --exclude='./.agents' \
        --exclude='./.codex' --exclude='./.aws' -cf - . \
        | tar -C "$install_dir" -xf -
fi

# ExecStart expands dollar signs; double them to keep executable paths literal.
exec_path=$(quote_unit_value "${quickshell_bin//\$/\$\$}")
service_path=$(quote_unit_value "PATH=$PATH")
cat > "$service_dir/$service_name" <<EOF
[Unit]
Description=Persona 3 Quickshell widgets
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
Environment=$service_path
ExecStart=$exec_path --no-duplicate -p "%h/.config/quickshell/p3r"
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF

# Share the current desktop connection with services started by the user manager.
session_variables=()
for variable in WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; do
    if [[ -v "$variable" ]]; then
        session_variables+=("$variable")
    fi
done
if (( ${#session_variables[@]} > 0 )); then
    systemctl --user import-environment "${session_variables[@]}"
fi

systemctl --user daemon-reload
systemctl --user enable "$service_name"

printf '\nInstalled widgets to %s\n' "$install_dir"
printf 'Enabled %s for graphical sessions.\n' "$service_name"
printf 'Start now: systemctl --user start %s\n' "$service_name"
printf 'After reinstalling: systemctl --user restart %s\n' "$service_name"
