import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Rectangle {
    id: tile
    required property var client
    readonly property var handle: Hyprland.toplevels.values.find(window =>
        String(window.address).replace(/^0x/, "") === String(client.address).replace(/^0x/, "")) || null
    radius: 5
    color: "#242630"
    border { color: "#777780"; width: 1 }
    clip: true
    ScreencopyView {
        id: capture
        anchors { fill: parent; margins: 1 }
        captureSource: tile.handle ? tile.handle.wayland : null
        live: tile.visible
        paintCursor: false
        constraintSize: Qt.size(Math.ceil(width * 1.5), Math.ceil(height * 1.5))
    }
    ShaderEffectSource {
        anchors.fill: capture
        sourceItem: capture
        hideSource: true
        live: capture.hasContent
    }
    Image {
        // Keep a stable badge over the live preview. A screencopy frame can
        // briefly be unavailable while an app resizes or changes workspace.
        anchors { left: parent.left; top: parent.top; margins: 5 }
        width: Math.min(22, parent.width / 3); height: width
        source: Quickshell.iconPath(tile.client.class.toLowerCase(), true)
        visible: status === Image.Ready
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 20; color: "#c0101016"
        visible: tile.width > 70 && tile.height > 35
        Text {
            anchors { fill: parent; margins: 3 }
            text: tile.client.title || tile.client.class
            elide: Text.ElideRight; color: "white"; font.pixelSize: 10
        }
    }
}
