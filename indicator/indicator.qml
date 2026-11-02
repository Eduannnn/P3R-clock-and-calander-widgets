import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../notch" as Notch

ShellRoot {
    id: indicator

    property real indicatorRightMargin: 8
    property real indicatorVerticalOffset: 2
    readonly property real notchBottom: calibration.valid
        ? calibration.rect.y + calibration.rect.height : 37.5
    readonly property int contentHeight: Math.max(1, Math.floor(notchBottom))
    readonly property real indicatorSize: Math.min(32, contentHeight - 4)

    Notch.NotchCalibration { id: calibration; screen: window.screen }
    ControlCenter {
        id: controlCenter
        screen: window.screen
        topInset: indicator.notchBottom
        batteryLevel: status.batteryLevel
    }
    IpcHandler {
        target: "controlCenter"
        function toggle(): void { controlCenter.toggle(); }
        function close(): void { controlCenter.opened = false; }
    }

    PanelWindow {
        id: window
        anchors { top: true; right: true }
        implicitWidth: indicator.indicatorSize + indicator.indicatorRightMargin
        implicitHeight: Math.ceil(Math.max(indicator.notchBottom,
            status.y + status.height))
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: status }
        WlrLayershell.namespace: "p3r-status-indicator"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ConnectionIndicator {
            id: status
            anchors { right: parent.right; rightMargin: indicator.indicatorRightMargin }
            y: (indicator.contentHeight - height) / 2 + indicator.indicatorVerticalOffset
            width: indicator.indicatorSize
            height: indicator.indicatorSize
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controlCenter.toggle()
            }
        }
    }
}
