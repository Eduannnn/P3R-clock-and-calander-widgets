import QtQuick
import QtQuick.Controls
import "../notch" as Notch
import "../common/AudioLevel.js" as AudioLevel

Rectangle {
    id: control
    required property string label
    required property string symbol
    property real value: 0
    property bool available: true
    signal adjusted(real level)
    signal iconClicked()
    implicitHeight: 64
    radius: 10
    color: "#27272b"

    Text {
        x: 10; y: 7
        text: control.label
        color: "#f5f5f7"
        font { pixelSize: 12; weight: Font.DemiBold }
    }
    Text {
        anchors { right: parent.right; rightMargin: 10; top: parent.top; topMargin: 7 }
        text: control.available ? AudioLevel.percentage(slider.value) + "%" : "Unavailable"
        color: "#aaaab2"
        font.pixelSize: 11
    }
    Notch.SfSymbol {
        x: 10; y: 33; width: 18; height: 18
        symbolName: control.symbol
        symbolColor: "#f5f5f7"
        fallbackIcon: control.label === "Display" ? "display-brightness" : "audio-volume-high"
        MouseArea { anchors.fill: parent; onClicked: control.iconClicked() }
    }
    Slider {
        id: slider
        x: 36; y: 26
        width: parent.width - 46; height: 32
        padding: 0
        from: 0; to: 1
        Binding {
            target: slider
            property: "value"
            value: control.value
            when: !slider.pressed
            restoreMode: Binding.RestoreNone
        }
        enabled: control.available
        onMoved: control.adjusted(value)
        background: Rectangle {
            id: track
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth; height: 16; radius: 8
            color: "#4a4a50"
            Rectangle {
                // Meet the thumb's centre at every value, including the ends.
                width: Math.max(0, Math.min(parent.width,
                    slider.handle.x + slider.handle.width / 2 - track.x))
                height: parent.height; radius: parent.radius
                color: "#f4ffffff"
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 20; height: 20; radius: 10
            color: "white"
            border { color: "#30323b50"; width: 1 }
        }
    }
}
