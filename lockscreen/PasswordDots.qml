import QtQuick

Row {
    id: dots
    property int count: 0
    property int dotSize: 10
    spacing: 6

    // Keep existing dots alive when a new character is typed. No password
    // characters are stored here, only the displayed length.
    function update() {
        const length = Math.min(18, Math.max(0, count));
        while (entries.count < length) entries.append({ token: entries.count });
        while (entries.count > length) entries.remove(entries.count - 1);
    }
    onCountChanged: update()
    Component.onCompleted: update()
    ListModel { id: entries }
    Repeater {
        model: entries
        delegate: Rectangle {
            id: dot
            width: dots.dotSize; height: width; radius: width / 2
            color: "white"
            ParallelAnimation {
                running: true
                NumberAnimation { target: dot; property: "opacity"; from: 0; to: 1; duration: 100 }
                NumberAnimation { target: dot; property: "scale"; from: 0.35; to: 1; duration: 150; easing.type: Easing.OutBack }
            }
        }
    }
}
