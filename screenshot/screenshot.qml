import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: preview

    property string imagePath: ""
    property string helperPath: ""
    property bool menuOpen: false
    property int previewWidth: 200
    property int previewMaxHeight: 170
    property int edgeMargin: 20
    property int displayDuration: 10000

    function dismiss() {
        imagePath = "";
        menuOpen = false;
        timeout.stop();
    }

    function action(name) {
        if (!imagePath || actionProcess.running) return;
        actionProcess.command = [helperPath, name, imagePath];
        actionProcess.running = true;
        dismiss();
    }

    IpcHandler {
        target: "screenshot"
        function dismiss(): void { preview.dismiss(); }
        function present(path: string, helper: string): void {
            if (!path.startsWith("/") || !path.endsWith(".png")
                || !helper.startsWith("/nix/store/") || !helper.endsWith("/bin/hypr-screenshot")) return;
            preview.imagePath = path;
            preview.helperPath = helper;
            preview.menuOpen = false;
            timeout.restart();
        }
    }

    Process { id: actionProcess }
    Timer { id: timeout; interval: preview.displayDuration; onTriggered: preview.dismiss() }

    PanelWindow {
        visible: preview.imagePath !== ""
        anchors { bottom: true; right: true }
        margins { bottom: preview.edgeMargin; right: preview.edgeMargin }
        implicitWidth: preview.previewWidth + 8
        implicitHeight: thumbnail.height + 8 + (preview.menuOpen ? actions.height + 8 : 0)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "p3r-screenshot-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: thumbnail
            width: parent.width
            height: Math.min(preview.previewMaxHeight, Math.round(preview.previewWidth / Math.max(0.01,
                image.sourceSize.height > 0 ? image.sourceSize.width / image.sourceSize.height : 1.6))) + 8
            color: "#202024"
            radius: 8
            border { color: "white"; width: 2 }

            Image {
                id: image
                anchors { fill: parent; margins: 4 }
                source: preview.imagePath ? "file://" + encodeURI(preview.imagePath).replace(/#/g, "%23").replace(/\?/g, "%3F") : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                hoverEnabled: true
                onEntered: timeout.stop()
                onExited: { if (!preview.menuOpen) timeout.restart(); }
                onClicked: {
                    preview.menuOpen = !preview.menuOpen;
                    if (preview.menuOpen) timeout.stop();
                    else timeout.restart();
                }
            }
        }

        Rectangle {
            id: actions
            visible: preview.menuOpen
            y: thumbnail.height + 8
            width: parent.width
            height: options.height + 8
            radius: 8
            color: "#f027272b"
            border.color: "#66ffffff"

            Column {
                id: options
                x: 4; y: 4
                width: parent.width - 8
                Repeater {
                    model: [
                        { label: "Copy", action: "--copy" },
                        { label: "Save to…", action: "--save-as" },
                        { label: "Share…", action: "--share" },
                        { label: "Delete", action: "--delete" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: options.width
                        height: 34
                        radius: 5
                        color: pointer.containsMouse ? "#35ffffff" : "transparent"
                        Text {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: modelData.label
                            color: modelData.action === "--delete" ? "#ff827b" : "white"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: preview.action(modelData.action)
                        }
                    }
                }
            }
        }
    }
}
