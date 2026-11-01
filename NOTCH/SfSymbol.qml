import QtQuick
import Quickshell
import Quickshell.Io

// Locally extracted SF artwork stays outside the repository. Recolour the
// generated white SVG in memory, preserving its original outlines and alpha.
Image {
    id: symbol
    required property string symbolName
    property color symbolColor: "white"
    property string fallbackIcon: "battery-good-charging"
    property string svg: ""
    readonly property string iconPath: (Quickshell.env("XDG_DATA_HOME")
        || Quickshell.env("HOME") + "/.local/share")
        + "/icons/SFSymbols/scalable/status/" + symbolName + ".svg"
    source: svg !== "" ? "data:image/svg+xml;utf8," + encodeURIComponent(
        svg.replace(/fill="#fff"/g, 'fill="' + String(symbolColor) + '"'))
        : Quickshell.iconPath(fallbackIcon, true)
    fillMode: Image.PreserveAspectFit
    sourceSize.width: Math.ceil(width * 2)
    sourceSize.height: Math.ceil(height * 2)
    FileView {
        path: symbol.iconPath
        printErrors: false
        onLoaded: symbol.svg = text()
        onLoadFailed: symbol.svg = ""
    }
}
