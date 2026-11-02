import QtQuick
import QtQuick.Controls
import "../notch" as Notch

Rectangle {
    id: menu
    property string confirmation: ""
    property var actions: [
        { action: "lock", label: "Lock", symbol: "lock.fill" },
        { action: "logout", label: "Sign Out…", symbol: "arrow.right.square" },
        { action: "reboot", label: "Restart…", symbol: "arrow.clockwise" },
        { action: "shutdown", label: "Shut Down…", symbol: "power" }
    ]
    property real reveal: visible ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    signal actionRequested(string action)
    radius: 10
    color: "#27272b"
    implicitHeight: confirmation ? confirmContents.implicitHeight + 20 : options.implicitHeight + 8
    height: implicitHeight * reveal
    opacity: reveal
    clip: true
    onVisibleChanged: { if (!visible) confirmation = ""; }

    Column {
        id: options
        x: 4; y: 4; width: parent.width - 8
        visible: menu.confirmation === ""
        Repeater {
            model: menu.actions
            delegate: Rectangle {
                required property var modelData
                width: options.width; height: 34; radius: 7
                color: pointer.containsMouse ? "#38383e" : "transparent"
                Notch.SfSymbol {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 15; height: 15
                    symbolName: modelData.symbol
                    symbolColor: "#f5f5f7"
                    fallbackIcon: "system-shutdown"
                }
                Text {
                    x: 36; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label; color: "#f5f5f7"; font.pixelSize: 12
                }
                MouseArea {
                    id: pointer
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "lock" || modelData.action === "suspend") menu.actionRequested(modelData.action);
                        else menu.confirmation = modelData.action;
                    }
                }
            }
        }
    }
    Column {
        id: confirmContents
        x: 10; y: 10; width: parent.width - 20; spacing: 10
        visible: menu.confirmation !== ""
        Text {
            text: menu.confirmation === "logout" ? "Sign out of this session?"
                : menu.confirmation === "reboot" ? "Restart the computer?" : "Shut down the computer?"
            width: parent.width; wrapMode: Text.Wrap
            color: "#f5f5f7"; font.pixelSize: 12
        }
        Row {
            spacing: 8
            Repeater {
                model: ["Cancel", "Confirm"]
                delegate: Button {
                    required property string modelData
                    width: (confirmContents.width - 8) / 2; height: 32
                    text: modelData
                    background: Rectangle { radius: 7; color: parent.hovered ? "#48484e" : "#38383e" }
                    contentItem: Text { text: parent.text; color: "#f5f5f7"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 }
                    onClicked: {
                        if (modelData === "Cancel") menu.confirmation = "";
                        else menu.actionRequested(menu.confirmation);
                    }
                }
            }
        }
    }
}
