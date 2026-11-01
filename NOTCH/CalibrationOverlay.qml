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
    property bool fineAdjustment: false
    property bool showDetails: false
    property real rectWidth: 310 / store.compositorScale
    property real rectHeight: store.driverHeight / store.compositorScale
    property real horizontalOffset: 0
    property real cornerRadius: 8
    readonly property real rectX: store.screen ? (store.screen.width - rectWidth) / 2 + horizontalOffset : 0
    readonly property var draft: ({ x: rectX, y: 0, width: rectWidth, height: rectHeight, cornerRadius: cornerRadius })
    signal closed()

    function resetDraft() {
        const r = store.valid ? store.rect : null;
        rectWidth = r ? r.width : 310 / store.compositorScale;
        rectHeight = r ? r.height : store.driverHeight / store.compositorScale;
        horizontalOffset = r ? r.x + r.width / 2 - store.screen.width / 2 : 0;
        cornerRadius = r ? r.cornerRadius : 8;
    }
    function open() {
        resetDraft();
        showRectangle = true;
        showDetails = false;
        store.error = "";
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
            text: "Adjust the rectangle until the colored edges disappear behind your camera notch."
            color: "black"; font.pixelSize: 13
        }
    }

    component Measurement: RowLayout {
        id: measurement
        property string label: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 600
        property real step: calibration.fineAdjustment ? 0.1 : 1
        signal adjusted(real value)
        spacing: 8
        Text { text: measurement.label; color: "white"; Layout.preferredWidth: 116; font.pixelSize: 14 }
        Controls.Button {
            text: "−"; Layout.preferredWidth: 32
            enabled: measurement.value > measurement.minimum
            Accessible.name: "Decrease " + measurement.label
            onClicked: measurement.adjusted(Math.max(measurement.minimum, measurement.value - measurement.step))
        }
        Controls.Slider {
            Layout.fillWidth: true
            from: measurement.minimum; to: measurement.maximum
            value: measurement.value
            stepSize: measurement.step
            Accessible.name: measurement.label
            onMoved: measurement.adjusted(value)
        }
        Controls.Button {
            text: "+"; Layout.preferredWidth: 32
            enabled: measurement.value < measurement.maximum
            Accessible.name: "Increase " + measurement.label
            onClicked: measurement.adjusted(Math.min(measurement.maximum, measurement.value + measurement.step))
        }
        Controls.TextField {
            Layout.preferredWidth: 84
            Accessible.name: measurement.label + " in logical pixels"
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
        implicitWidth: 640
        implicitHeight: panel.implicitHeight + 40
        color: "#151923"
        onClosed: calibration.close()
        Shortcut { sequence: "Escape"; onActivated: calibration.close() }
        ColumnLayout {
            id: panel
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 14
            Text { text: "Fit your widgets around the notch"; color: "white"; font.pixelSize: 21; font.bold: true }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b8c4d8"; font.pixelSize: 13
                text: "1. Look at the bright strip at the top of your display.\n2. Adjust the rectangle to match the camera cutout.\n3. Save when the colored edges disappear behind it.\n\nSetup opens on launch until you save a calibration. Changes stay a preview until you save."
            }
            Measurement { Layout.fillWidth: true; label: "Width"; value: calibration.rectWidth; minimum: 10; maximum: Math.min(700, calibration.store.screen ? calibration.store.screen.width : 700); onAdjusted: value => { calibration.rectWidth = value; calibration.cornerRadius = Math.min(calibration.cornerRadius, value / 2); } }
            Measurement { Layout.fillWidth: true; label: "Height"; value: calibration.rectHeight; minimum: 1; maximum: 120; onAdjusted: value => { calibration.rectHeight = value; calibration.cornerRadius = Math.min(calibration.cornerRadius, value / 2); } }
            Measurement { Layout.fillWidth: true; label: "Left / right"; value: calibration.horizontalOffset; minimum: -250; maximum: 250; onAdjusted: value => calibration.horizontalOffset = value }
            Measurement { Layout.fillWidth: true; label: "Corner radius"; value: calibration.cornerRadius; maximum: Math.min(calibration.rectWidth, calibration.rectHeight) / 2; onAdjusted: value => calibration.cornerRadius = value }
            Controls.CheckBox { text: "Fine adjustment (0.1 px steps)"; checked: calibration.fineAdjustment; onToggled: calibration.fineAdjustment = checked }
            RowLayout {
                Controls.Button { text: "Undo adjustments"; onClicked: calibration.resetDraft() }
                Controls.Button { text: "Center horizontally"; onClicked: calibration.horizontalOffset = 0 }
            }
            Controls.CheckBox { text: "Show alignment rectangle"; checked: calibration.showRectangle; onToggled: calibration.showRectangle = checked }
            Controls.Button { text: calibration.showDetails ? "Hide measurements" : "Show measurements"; onClicked: calibration.showDetails = !calibration.showDetails }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#b8c4d8"; font.pixelSize: 13
                visible: calibration.showDetails
                text: "Logical: x " + calibration.rectX.toFixed(3) + ", y 0, " + calibration.rectWidth.toFixed(3) + " × " + calibration.rectHeight.toFixed(3)
                    + "\nPhysical estimate: " + (calibration.rectWidth * calibration.store.compositorScale).toFixed(1) + " × " + (calibration.rectHeight * calibration.store.compositorScale).toFixed(1)
                    + " px at " + (calibration.store.compositorScale * 100).toFixed(0) + "%"
                    + "\nValues use logical pixels. Display scaling and KDE settings stay unchanged."
                    + "\nSaved to: " + calibration.store.configPath
            }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: calibration.store.error; visible: text !== ""; color: "#ff8888" }
            RowLayout {
                Layout.fillWidth: true
                Controls.Button { text: calibration.store.valid ? "Cancel" : "Set up later"; onClicked: calibration.close() }
                Item { Layout.fillWidth: true }
                Controls.Button {
                    text: calibration.store.saving ? "Saving…" : "Save calibration"
                    enabled: !calibration.store.saving && calibration.store.validRectangle(calibration.draft)
                    onClicked: calibration.store.save(calibration.draft)
                }
            }
            Text { Layout.fillWidth: true; text: "Reopen anytime: quickshell ipc -p . call notch calibrate"; color: "#8190a6"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
        }
    }
}
