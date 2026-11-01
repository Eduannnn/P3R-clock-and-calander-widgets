import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Wayland

QtObject {
    id: calibration
    required property var store
    property bool active: false
    property bool showRectangle: true
    property real rectWidth: 310 / store.compositorScale
    property real rectHeight: store.driverHeight / store.compositorScale
    property real horizontalOffset: 0
    property real cornerRadius: 8
    readonly property real rectX: store.screen ? (store.screen.width - rectWidth) / 2 + horizontalOffset : 0
    readonly property var draft: ({ x: rectX, y: 0, width: rectWidth, height: rectHeight, cornerRadius: cornerRadius })
    signal closed()

    function open() {
        const r = store.valid ? store.rect : null;
        rectWidth = r ? r.width : 310 / store.compositorScale;
        rectHeight = r ? r.height : store.driverHeight / store.compositorScale;
        horizontalOffset = r ? r.x + r.width / 2 - store.screen.width / 2 : 0;
        cornerRadius = r ? r.cornerRadius : 8;
        showRectangle = true;
        active = true;
    }
    function close() { active = false; closed(); }
    property Connections saved: Connections {
        target: calibration.store
        function onSaveCompleted() { calibration.close(); }
    }

    property PanelWindow overlay: PanelWindow {
        screen: calibration.store.screen
        visible: calibration.active && calibration.showRectangle
        anchors { top: true; left: true; right: true }
        implicitHeight: Math.max(120, calibration.rectHeight + 50)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region { width: 0; height: 0 }
        Rectangle { anchors.fill: parent; color: "white" }
        Rectangle {
            x: calibration.rectX; y: 0
            width: calibration.rectWidth; height: calibration.rectHeight
            radius: calibration.cornerRadius
            color: "#ff00e6"
            border.color: "#00c000"
            border.width: 1 / calibration.store.compositorScale
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(calibration.rectHeight + 10, 75)
            text: "Match the colored rectangle to the camera cutout. Green/pink fringes reveal misalignment."
            color: "black"; font.pixelSize: 13
        }
    }

    component Measurement: RowLayout {
        id: measurement
        property string label: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 600
        signal adjusted(real value)
        spacing: 12
        Text { text: measurement.label; color: "white"; Layout.preferredWidth: 120; font.pixelSize: 14 }
        Controls.Slider {
            Layout.fillWidth: true
            from: measurement.minimum; to: measurement.maximum
            value: measurement.value
            onMoved: measurement.adjusted(value)
        }
        Controls.TextField {
            Layout.preferredWidth: 100
            text: measurement.value.toFixed(3)
            selectByMouse: true
            validator: DoubleValidator { bottom: measurement.minimum; top: measurement.maximum; decimals: 3; notation: DoubleValidator.StandardNotation }
            onEditingFinished: {
                const number = Number(text);
                if (Number.isFinite(number) && number >= measurement.minimum && number <= measurement.maximum) measurement.adjusted(number);
                text = Qt.binding(() => measurement.value.toFixed(3));
            }
        }
    }

    property FloatingWindow controls: FloatingWindow {
        title: "Notch calibration"
        visible: calibration.active
        implicitWidth: 600
        implicitHeight: panel.implicitHeight + 40
        color: "#151923"
        onClosed: calibration.close()
        Shortcut { sequence: "Escape"; onActivated: calibration.close() }
        ColumnLayout {
            id: panel
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 14
            Text { text: "Align the physical camera notch"; color: "white"; font.pixelSize: 21; font.bold: true }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b8c4d8"; font.pixelSize: 13
                text: "All controls use logical pixels. The screenshot's ~310px width is only a starting estimate. Match the rectangle visually before saving."
            }
            Measurement { Layout.fillWidth: true; label: "Width"; value: calibration.rectWidth; minimum: 10; maximum: Math.min(700, calibration.store.screen ? calibration.store.screen.width : 700); onAdjusted: value => { calibration.rectWidth = value; calibration.cornerRadius = Math.min(calibration.cornerRadius, value / 2); } }
            Measurement { Layout.fillWidth: true; label: "Height"; value: calibration.rectHeight; minimum: 1; maximum: 120; onAdjusted: value => { calibration.rectHeight = value; calibration.cornerRadius = Math.min(calibration.cornerRadius, value / 2); } }
            Measurement { Layout.fillWidth: true; label: "Horizontal offset"; value: calibration.horizontalOffset; minimum: -250; maximum: 250; onAdjusted: value => calibration.horizontalOffset = value }
            Measurement { Layout.fillWidth: true; label: "Corner radius"; value: calibration.cornerRadius; maximum: Math.min(calibration.rectWidth, calibration.rectHeight) / 2; onAdjusted: value => calibration.cornerRadius = value }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b8c4d8"; font.pixelSize: 13
                text: "Logical: x " + calibration.rectX.toFixed(3) + ", y 0, " + calibration.rectWidth.toFixed(3) + " × " + calibration.rectHeight.toFixed(3)
                    + "\nPhysical estimate: " + (calibration.rectWidth * calibration.store.compositorScale).toFixed(1) + " × " + (calibration.rectHeight * calibration.store.compositorScale).toFixed(1)
                    + " px at " + (calibration.store.compositorScale * 100).toFixed(0) + "%"
                    + "\nDriver reports " + calibration.store.driverHeight + "px height; width and corners require visual alignment."
            }
            Controls.CheckBox { text: "Show calibration rectangle"; checked: calibration.showRectangle; onToggled: calibration.showRectangle = checked }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: calibration.store.error; visible: text !== ""; color: "#ff8888" }
            RowLayout {
                Layout.fillWidth: true
                Controls.Button { text: "Close without saving"; onClicked: calibration.close() }
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: calibration.store.saving ? "Saving…" : "Save & close"
                    enabled: !calibration.store.saving && calibration.rectX >= 0
                        && calibration.rectX + calibration.rectWidth <= (calibration.store.screen ? calibration.store.screen.width : 0)
                    onClicked: calibration.store.save(calibration.draft)
                }
            }
            Text { Layout.fillWidth: true; text: calibration.store.configPath; color: "#8190a6"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
        }
    }
}
