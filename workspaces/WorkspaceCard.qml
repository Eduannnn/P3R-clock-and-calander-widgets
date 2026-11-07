import QtQuick
import Quickshell.Widgets
import "../notch" as Notch
import "StableModel.js" as Stable

ClippingRectangle {
    id: card
    required property var workspace
    required property var controller
    property string dragKind: "workspace"
    property int workspaceId: workspace.id
    readonly property var monitor: controller.monitorFor(workspace.monitorID)
    readonly property real outputWidth: monitor ? monitor.width / monitor.scale : 1707
    readonly property real outputHeight: monitor ? monitor.height / monitor.scale : 1109
    readonly property var windows: controller.clients.filter(client => client.mapped && !client.hidden
        && !client.minimized && client.workspace.id === workspaceId)
    ListModel { id: windowModel; dynamicRoles: true }
    function synchronizeWindows() { Stable.synchronize(windowModel, windows, "address"); }
    onWindowsChanged: Qt.callLater(synchronizeWindows)
    Component.onCompleted: synchronizeWindows()
    height: width * outputHeight / outputWidth + 40
    radius: 12
    // Preserve the layout coordinates while clipping previews inside the
    // rounded selection border, rather than only their rectangular bounds.
    contentInsideBorder: false
    color: "#d01b1d26"
    border { color: drop.containsDrag ? "#65ddff" : controller.activeWorkspace === workspaceId ? "#5472ff" : "#686b7b"; width: 2 }

    Item {
        id: header
        width: parent.width; height: 38
        Text {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            text: card.workspace.name === String(card.workspaceId) ? "Desktop " + card.workspaceId : card.workspace.name
            width: parent.width - (card.workspaceId > 1 ? 82 : 44)
            elide: Text.ElideRight
            color: "white"; font { pixelSize: 13; weight: Font.DemiBold }
        }
        Text {
            anchors { right: parent.right; rightMargin: card.workspaceId > 1 ? 44 : 12; verticalCenter: parent.verticalCenter }
            text: "⠿"; color: "#b0b3c1"; font.pixelSize: 18
        }
        MouseArea {
            id: headerPointer
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => card.controller.beginPointer(card, headerPointer, mouse)
            onPositionChanged: mouse => { if (pressed) card.controller.movePointer(headerPointer, mouse); }
            onReleased: {
                const dragged = card.controller.endPointer();
                if (!dragged) card.controller.activateWorkspace(card.workspaceId);
            }
            onCanceled: card.controller.cancelDrag()
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 24; height: 24; radius: 12
            visible: card.workspaceId > 1
            color: closePointer.containsMouse ? "#48484e" : "#27272b"
            opacity: card.controller.busy ? 0.4 : 1
            Notch.SfSymbol {
                anchors.centerIn: parent; width: 11; height: 11
                symbolName: "xmark"; symbolColor: "white"; fallbackIcon: "window-close"
            }
            MouseArea {
                id: closePointer
                anchors.fill: parent
                hoverEnabled: true
                enabled: !card.controller.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: card.controller.deleteWorkspace(card.workspaceId)
            }
        }
    }
    Item {
        id: desktop
        x: 3; y: 38; width: parent.width - 6; height: parent.height - 41
        clip: true
        Rectangle { anchors.fill: parent; color: "#131a2d" }
        MouseArea { anchors.fill: parent; onClicked: card.controller.activateWorkspace(card.workspaceId) }
        Text {
            anchors.centerIn: parent
            text: "Empty desktop"; color: "#777f95"; font.pixelSize: 12
            visible: card.windows.length === 0
        }
        Repeater {
            model: windowModel
            delegate: WindowPreview {
                required property var entry
                client: entry
                x: (client.at[0] - (card.monitor ? card.monitor.x : 0)) / card.outputWidth * desktop.width
                y: (client.at[1] - (card.monitor ? card.monitor.y : 0)) / card.outputHeight * desktop.height
                width: Math.max(12, client.size[0] / card.outputWidth * desktop.width)
                height: Math.max(10, client.size[1] / card.outputHeight * desktop.height)
            }
        }
    }
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["workspace"]
        onDropped: event => {
            if (!event.source) return;
            card.controller.reorder(event.source.workspaceId, card.workspaceId);
            event.accepted = true;
        }
    }
}
