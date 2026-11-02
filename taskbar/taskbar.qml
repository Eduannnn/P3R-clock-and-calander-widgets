import QtQuick
import Quickshell
import Quickshell.Wayland
import "../notch" as Notch
import "../p3r-clock" as Clock

ShellRoot {
    id: taskbar
    property bool backgroundEnabled: false
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
        visible: taskbar.backgroundEnabled && windows.compact
        anchors { top: true; left: true; right: true }
        implicitHeight: Math.ceil(calibration.valid
            ? calibration.rect.y + calibration.rect.height : 37.5)
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "p3r-top-strip"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    }
}
