import QtQuick
import QtQuick.Controls
import "../notch" as Notch

Rectangle {
    id: control
    required property string title
    required property string subtitle
    required property string symbol
    property string fallbackIcon: "preferences-system"
    property color accent: "#168bff"
    property bool active: false
    property bool available: true
    signal toggled()
    implicitHeight: 48
    radius: 10
    color: pointer.containsMouse ? "#36363c" : "#27272b"
    opacity: available ? 1 : 0.5
    Rectangle {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        width: 28; height: 28; radius: 14
        color: control.active ? control.accent : "#48484e"
        Notch.SfSymbol {
            anchors.centerIn: parent; width: 16; height: 16
            symbolName: control.symbol
            symbolColor: control.active ? "white" : "#aaaab2"
            fallbackIcon: control.fallbackIcon
        }
    }
    Column {
        x: 48; width: parent.width - 96
        anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Text { width: parent.width; text: control.title; color: "#f5f5f7"; elide: Text.ElideRight; font { pixelSize: 12; weight: Font.DemiBold } }
        Text { width: parent.width; text: control.subtitle; color: "#aaaab2"; elide: Text.ElideRight; font.pixelSize: 10 }
    }
    Rectangle {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: 32; height: 18; radius: 9
        color: control.active ? control.accent : "#45374364"
        Rectangle {
            x: control.active ? 16 : 2; y: 2
            width: 14; height: 14; radius: 7; color: "white"
            Behavior on x { NumberAnimation { duration: 120 } }
        }
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        enabled: control.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled()
    }
    Accessible.name: title
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: active
}
