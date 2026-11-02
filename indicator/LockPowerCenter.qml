import QtQuick
import QtQuick.Controls
import Quickshell
import "../notch" as Notch

Item {
    id: center
    property bool opened: false
    property real reveal: opened ? 1 : 0
    property real topInset: 38
    property real notchCenterX: width / 2
    property real earRadius: 6
    property real notchWidth: 208
    property real statusWidth: 50
    readonly property var sink: null
    signal closed()
    anchors.fill: parent
    z: 1000
    visible: opened || reveal > 0.001
    enabled: opened
    Behavior on reveal { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    function toggle() { opened = !opened; }
    function performPowerAction(action) {
        const commands = {
            suspend: ["systemctl", "suspend"],
            reboot: ["systemctl", "reboot"],
            shutdown: ["systemctl", "poweroff"]
        };
        if (!commands[action]) return;
        opened = false;
        Quickshell.execDetached(commands[action]);
    }
    onOpenedChanged: {
        options.confirmation = "";
        if (opened) Qt.callLater(() => center.forceActiveFocus());
        else closed();
    }
    Keys.onEscapePressed: opened = false
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: center.opened = false }

    Rectangle {
        id: card
        x: Math.max(8, Math.min(parent.width - width - 8, center.notchCenterX - width / 2))
        y: -(1 - center.reveal) * 8
        width: Math.min(Math.max(320, center.notchWidth + 2 * center.statusWidth), parent.width - 24)
        height: center.topInset + 14 + options.height
        opacity: center.reveal
        radius: 14
        topLeftRadius: 0
        topRightRadius: 0
        color: "black"
        Notch.TopEdgeEars { width: parent.width; radius: center.earRadius }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        ConnectionIndicator {
            x: center.notchCenterX - center.notchWidth / 2 - center.statusWidth + 8 - card.x
            y: (center.topInset - height) / 2 - 2
            width: 32; height: 32
        }
        ToolButton {
            anchors { right: parent.right; rightMargin: 8 }
            y: Math.max(0, (center.topInset - height) / 2)
            width: 26; height: 26
            text: "×"
            background: Rectangle { radius: 7; color: parent.hovered ? "#38383e" : "transparent" }
            contentItem: Text {
                text: "×"; color: "#aaaab2"; font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            onClicked: center.opened = false
        }
        PowerMenu {
            id: options
            x: 8; y: center.topInset + 6; width: parent.width - 16
            actions: [
                { action: "suspend", label: "Sleep", symbol: "moon.fill" },
                { action: "reboot", label: "Restart…", symbol: "arrow.clockwise" },
                { action: "shutdown", label: "Shut Down…", symbol: "power" }
            ]
            onActionRequested: action => center.performPowerAction(action)
        }
    }
}
