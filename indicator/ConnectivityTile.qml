import QtQuick
import QtQuick.Controls
import "../notch" as Notch

Rectangle {
    id: tile
    required property string title
    required property string subtitle
    required property string symbol
    required property string fallbackIcon
    property bool active: false
    property bool available: true
    signal toggled()
    signal detailsRequested()
    implicitHeight: 72
    radius: 10
    color: pointer.containsMouse ? "#36363c" : "#27272b"
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.detailsRequested()
    }
    Rectangle {
        x: 10; y: 8; width: 26; height: 26; radius: 13
        color: tile.active ? "#168bff" : "#48484e"
        Notch.SfSymbol {
            visible: tile.symbol !== "bluetooth"
            anchors.centerIn: parent
            width: 16; height: 16
            symbolName: tile.symbol
            symbolColor: tile.active ? "white" : "#aaaab2"
            fallbackIcon: tile.fallbackIcon
        }
        // The local SF Symbols set has no Bluetooth alias. Draw its actual
        // mark explicitly instead of substituting a cellular/antenna symbol.
        Canvas {
            anchors.centerIn: parent
            width: 16; height: 16
            visible: tile.symbol === "bluetooth"
            property color strokeColor: tile.active ? "white" : "#aaaab2"
            onStrokeColorChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(width / 24, height / 24);
                ctx.strokeStyle = strokeColor;
                ctx.lineWidth = 2.2;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(7, 7);
                ctx.lineTo(17, 17);
                ctx.lineTo(12, 22);
                ctx.lineTo(12, 2);
                ctx.lineTo(17, 7);
                ctx.lineTo(7, 17);
                ctx.stroke();
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: tile.available
            onClicked: tile.toggled()
            hoverEnabled: true
            ToolTip.visible: containsMouse
            ToolTip.text: "Turn " + tile.title + (tile.active ? " off" : " on")
        }
    }
    Text {
        anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 8 }
        text: "›"
        color: "#626875"
        font.pixelSize: 22
    }
    Text {
        x: 10; y: 39
        text: tile.title
        color: "#f5f5f7"
        font { pixelSize: 12; weight: Font.DemiBold }
    }
    Text {
        x: 10; y: 55; width: parent.width - 20
        text: tile.subtitle
        elide: Text.ElideRight
        color: "#aaaab2"
        font.pixelSize: 10
    }
}
