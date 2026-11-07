import QtQuick
import QtQuick.Controls
import Quickshell.Services.Pipewire
import "../notch" as Notch

ComboBox {
    id: selector
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
    readonly property var activeOutput: Pipewire.defaultAudioSink
    function deviceName(node) { return node ? node.description || node.nickname || node.name : "No output devices"; }

    model: outputs
    currentIndex: outputs.indexOf(activeOutput)
    displayText: deviceName(activeOutput)
    enabled: outputs.length > 0
    implicitHeight: 30
    leftPadding: 9
    rightPadding: 30
    onActivated: index => {
        const output = outputs[index];
        if (output) Pipewire.preferredDefaultAudioSink = output;
    }
    Accessible.name: "Audio output device"
    background: Rectangle {
        radius: 6
        color: selector.down ? "#4a4a50" : selector.hovered ? "#414147" : "#34343a"
        border.color: selector.activeFocus ? "#6578ff" : "transparent"
    }
    contentItem: Text {
        text: selector.displayText
        color: selector.enabled ? "#f5f5f7" : "#aaaab2"
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Notch.SfSymbol {
        x: selector.width - width - 9
        y: (selector.height - height) / 2
        width: 11; height: 11
        symbolName: "chevron.down"
        symbolColor: "#aaaab2"
        fallbackIcon: "arrow-down"
    }
    delegate: ItemDelegate {
        id: device
        required property var modelData
        required property int index
        width: selector.width - 8
        height: 34
        highlighted: selector.highlightedIndex === index
        background: Rectangle { radius: 6; color: device.highlighted ? "#48484e" : "transparent" }
        contentItem: Item {
            Text {
                anchors { left: parent.left; right: check.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: selector.deviceName(device.modelData)
                color: "#f5f5f7"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Notch.SfSymbol {
                id: check
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 12; height: 12
                visible: device.modelData === selector.activeOutput
                symbolName: "checkmark"
                symbolColor: "white"
                fallbackIcon: "emblem-ok-symbolic"
            }
        }
    }
    popup: Popup {
        y: selector.height + 4
        width: selector.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 180)
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { radius: 8; color: "#303036"; border.color: "#505057" }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: selector.popup.visible ? selector.delegateModel : null
            currentIndex: selector.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
        }
    }
}
