import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../notch" as Notch
import "../p3r-clock" as Clock
import "../common" as Common

ShellRoot {
    id: taskbar
    property bool backgroundEnabled: false
    readonly property bool hyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property var fullscreenWindows: hyprland ? clients.result.filter(window => {
        if (!window.mapped || window.hidden || window.minimized
            || !window.fullscreen) return false;
        const output = outputs.result.find(output => output.name === strip.screen?.name);
        return output && window.monitor === output.id && (window.pinned
            || window.workspace?.id === output.activeWorkspace?.id
            || (output.specialWorkspace?.id !== 0 && window.workspace?.id === output.specialWorkspace?.id));
    }) : []
    readonly property bool desktopFullscreen: fullscreenWindows.some(window => !(window.fullscreenClient & 2))
    readonly property bool nativeFullscreen: fullscreenWindows.some(window => !!(window.fullscreenClient & 2))
    Binding {
        target: Common.FullscreenState; property: "nativeScreen"
        value: taskbar.nativeFullscreen ? strip.screen.name : ""
    }
    function refresh() { if (hyprland) { clients.refresh(); outputs.refresh(); } }
    IpcHandler {
        target: "taskbar"
        function status(): string {
            return JSON.stringify({ black: taskbar.desktopFullscreen, native: taskbar.nativeFullscreen, screen: strip.screen?.name,
                clients: clients.result.length, outputs: outputs.result.length,
                pending: clients.pending, states: clients.result.filter(w => w.fullscreen)
                    .map(w => ({ internal: w.fullscreen, client: w.fullscreenClient, monitor: w.monitor })) });
        }
    }
    Common.HyprlandQuery { id: clients; request: "j/clients" }
    Common.HyprlandQuery { id: outputs; request: "j/monitors" }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^(fullscreen|workspace|focusedmon|activewindow|openwindow|closewindow|movewindow|moveworkspace|monitoradded|monitorremoved|configreloaded)/.test(event.name))
                Qt.callLater(taskbar.refresh);
        }
    }
    Component.onCompleted: refresh()
    Notch.NotchCalibration { id: calibration; screen: strip.screen }
    Clock.WindowLayoutState {
        id: windows
        screen: strip.screen
        // Match any visible application on this screen's current workspace.
        clockRect: Qt.rect(screen ? screen.x : 0, screen ? screen.y : 0,
            screen ? screen.width : 0, screen ? screen.height : 0)
    }

    PanelWindow {
        id: strip
        // Keep this surface below the other overlay widgets by creating it
        // first. Changing only its color avoids remapping it above the clock.
        visible: taskbar.hyprland || (taskbar.backgroundEnabled && windows.compact)
        anchors { top: true; left: true; right: true }
        implicitHeight: Math.ceil(calibration.valid
            ? calibration.rect.y + calibration.rect.height : 37.5)
        color: taskbar.desktopFullscreen || (taskbar.backgroundEnabled && windows.compact) ? "black" : "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "p3r-top-strip"
        WlrLayershell.layer: taskbar.hyprland ? WlrLayer.Overlay : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
}
