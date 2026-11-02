import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: state
    property var screen: null
    // Always test the full clock's resting bounds, never its animated size.
    property rect clockRect: Qt.rect(0, 0, 0, 0)
    readonly property bool kde: Quickshell.env("XDG_CURRENT_DESKTOP").toLowerCase().includes("kde")
    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property HyprlandWindowState hyprlandState: HyprlandWindowState {
        enabled: state.hyprland
        clockRect: state.clockRect
    }
    property var windowBounds: []
    readonly property bool compact: screen !== null && (hyprland ? hyprlandState.compact : windowBounds.some(frame =>
        frame.x < clockRect.x + clockRect.width && frame.x + frame.width > clockRect.x
        && frame.y < clockRect.y + clockRect.height && frame.y + frame.height > clockRect.y))
    readonly property string helper: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share")
        + "/p3r-widgets/bin/p3r-clock-window-state"
    property Process monitor: Process {
        running: state.kde
        command: ["sh", "-c", 'if [ -x "$1" ]; then exec "$1"; else echo "Run p3r-clock/setup-window-state.sh for KDE window-state tracking." >&2; exit 127; fi', "clock-window-state", state.helper]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line);
                    if (Array.isArray(data.windows) && data.windows.every(frame =>
                        frame && [frame.x, frame.y, frame.width, frame.height].every(value =>
                            typeof value === "number" && Number.isFinite(value))
                        && frame.width > 0 && frame.height > 0)) state.windowBounds = data.windows;
                } catch (error) { console.warn("Invalid window-state monitor response"); }
            }
        }
        stderr: SplitParser { onRead: line => console.warn(line) }
        onExited: (code, status) => {
            state.windowBounds = [];
            if (code !== 127) retry.restart();
        }
    }
    property Timer retry: Timer { interval: 3000; onTriggered: state.monitor.running = true }
}
