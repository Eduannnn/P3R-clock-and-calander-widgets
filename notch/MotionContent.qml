import QtQuick

Item {
    id: content
    property bool active: false
    property real entranceOffset: 0
    opacity: active ? 1 : 0
    visible: opacity > 0.001
    enabled: active
    // Give the black shape a head start, and clear outgoing text quickly.
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: content.active ? 35 : 0 }
            NumberAnimation {
                duration: content.active ? 145 : 75
                easing.type: Easing.OutCubic
            }
        }
    }
    transform: Translate { y: (1 - content.opacity) * content.entranceOffset }
}
