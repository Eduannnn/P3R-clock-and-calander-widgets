import QtQuick

// Qt's spring units differ from SwiftUI's duration/bounce API. These values
// are tuned for the notch, with velocity preserved when a Behavior retargets.
SpringAnimation {
    property real responseMs: 280
    property bool smooth: false
    readonly property real tempo: 280 / Math.max(120, responseMs)
    spring: Math.min(5, 4.2 * tempo * tempo)
    damping: Math.min(1, (smooth ? 0.54 : 0.46) * tempo)
    epsilon: 0.05
}
