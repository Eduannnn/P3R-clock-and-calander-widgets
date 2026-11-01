import QtQuick

// Two identical copies meet at the loop boundary without reversing or jumping.
Item {
    id: ribbon
    property string text: ""
    property string fontFamily: "sans-serif"
    property real pixelSize: 16
    property int weight: Font.DemiBold
    property color textColor: "white"
    property bool active: false
    property var resetKey: null
    property real pixelsPerSecond: 30
    property real gap: 36
    property int readPauseMs: 1500
    property real edgeFadeWidth: 12
    property bool scrolling: false
    property int edgeTransitionMs: 200
    property int edgeLeadMs: 200
    readonly property int scrollDuration: Math.max(1, overflow / Math.max(1, pixelsPerSecond) * 1000)
    readonly property int wrapDuration: Math.max(1, (cycleWidth - overflow) / Math.max(1, pixelsPerSecond) * 1000)
    readonly property real overflow: Math.max(0, first.implicitWidth - width)
    readonly property real startX: 0
    readonly property real endX: -overflow
    readonly property real cycleWidth: first.implicitWidth + gap
    implicitHeight: first.implicitHeight
    clip: true

    function restart() {
        motion.stop();
        scrolling = false;
        strip.x = startX;
        if (active && overflow > 0) motion.start();
    }
    onTextChanged: Qt.callLater(restart)
    onOverflowChanged: restart()
    onCycleWidthChanged: restart()
    onActiveChanged: restart()
    onResetKeyChanged: restart()
    Component.onCompleted: restart()

    Item {
        id: strip
        width: ribbon.cycleWidth * 2
        height: first.implicitHeight
        Text {
            id: first
            text: ribbon.text
            textFormat: Text.PlainText
            color: ribbon.textColor
            font.family: ribbon.fontFamily
            font.pixelSize: ribbon.pixelSize
            font.weight: ribbon.weight
        }
        Text {
            x: ribbon.cycleWidth
            visible: ribbon.overflow > 0
            text: ribbon.text
            textFormat: Text.PlainText
            color: ribbon.textColor
            font.family: ribbon.fontFamily
            font.pixelSize: ribbon.pixelSize
            font.weight: ribbon.weight
        }
    }
    // The notch background is black, so these small overlays soften the edges
    // without a shader or an extra offscreen texture for each text row.
    Rectangle {
        anchors.left: parent.left
        width: Math.min(ribbon.edgeFadeWidth, ribbon.width / 4)
        height: parent.height
        visible: ribbon.overflow > 0
        opacity: ribbon.scrolling ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: ribbon.edgeTransitionMs; easing.type: Easing.InOutQuad }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "black" }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        anchors.right: parent.right
        width: Math.min(ribbon.edgeFadeWidth, ribbon.width / 4)
        height: parent.height
        visible: ribbon.overflow > 0
        opacity: ribbon.scrolling ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: ribbon.edgeTransitionMs; easing.type: Easing.InOutQuad }
        }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "black" }
        }
    }
    SequentialAnimation {
        id: motion
        loops: Animation.Infinite
        PropertyAction { target: ribbon; property: "scrolling"; value: false }
        PropertyAction { target: strip; property: "x"; value: ribbon.startX }
        PauseAnimation { duration: Math.max(0, ribbon.readPauseMs - ribbon.edgeLeadMs) }
        PropertyAction { target: ribbon; property: "scrolling"; value: true }
        PauseAnimation { duration: Math.min(ribbon.readPauseMs, ribbon.edgeLeadMs) }
        ParallelAnimation {
            NumberAnimation {
                target: strip
                property: "x"
                from: ribbon.startX
                to: ribbon.endX
                duration: ribbon.scrollDuration
                easing.type: Easing.Linear
            }
            SequentialAnimation {
                PauseAnimation { duration: Math.max(0, ribbon.scrollDuration - ribbon.edgeLeadMs) }
                PropertyAction { target: ribbon; property: "scrolling"; value: false }
            }
        }
        PauseAnimation { duration: Math.max(0, ribbon.readPauseMs - ribbon.edgeLeadMs) }
        PropertyAction { target: ribbon; property: "scrolling"; value: true }
        PauseAnimation { duration: Math.min(ribbon.readPauseMs, ribbon.edgeLeadMs) }
        ParallelAnimation {
            NumberAnimation {
                target: strip
                property: "x"
                from: ribbon.endX
                to: ribbon.startX - ribbon.cycleWidth
                duration: ribbon.wrapDuration
                easing.type: Easing.Linear
            }
            SequentialAnimation {
                PauseAnimation { duration: Math.max(0, ribbon.wrapDuration - ribbon.edgeLeadMs) }
                PropertyAction { target: ribbon; property: "scrolling"; value: false }
            }
        }
    }
}
