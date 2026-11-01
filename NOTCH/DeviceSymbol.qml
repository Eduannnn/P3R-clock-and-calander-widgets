import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: symbol
    property string kind: "bluetooth"
    property string fallbackIcon: "bluetooth"
    property bool available: false
    property real glyphHeight: Math.min(width, height) * 5 / 7
    // Normalise visible height and optical centre inside the existing icon slot.
    // Values account for each SF glyph's padding and distribution of filled pixels.
    readonly property var alignment: {
        switch (kind) {
        case "controller": return [1.103, -0.08, 0.12];
        case "headphones": return [1.080, 0, -1.17];
        case "earbuds": return [1.094, 0, 1.85];
        case "keyboard": return [1.103, 0, -0.17];
        case "mouse": return [1.067, 0, -0.51];
        case "speaker": return [1.085, 1.72, 0];
        case "phone": return [1.067, 0, 0];
        default: return [1.080, 0, 1.29];
        }
    }
    readonly property string symbolName: {
        switch (kind) {
        case "controller": return "gamecontroller.fill";
        case "headphones": return "headphones";
        case "earbuds": return "earbuds";
        case "keyboard": return "keyboard";
        case "mouse": return "computermouse.fill";
        case "speaker": return "speaker.wave.2.fill";
        case "phone": return "iphone";
        default: return "antenna.radiowaves.left.and.right";
        }
    }
    readonly property string iconPath: (Quickshell.env("XDG_DATA_HOME")
        || Quickshell.env("HOME") + "/.local/share")
        + "/icons/SFSymbols/scalable/status/" + symbolName + ".svg"
    readonly property string themePath: Quickshell.iconPath(fallbackIcon, true)
        || Quickshell.iconPath("preferences-system-bluetooth", true)

    FileView {
        path: symbol.iconPath
        printErrors: false
        watchChanges: true
        onLoaded: symbol.available = true
        onLoadFailed: symbol.available = false
        onFileChanged: reload()
    }
    Image {
        id: artwork
        readonly property real aspectRatio: implicitHeight > 0 ? implicitWidth / implicitHeight : 1
        height: symbol.glyphHeight * (symbol.available ? symbol.alignment[0] : 1)
        width: height * aspectRatio
        x: (parent.width - width) / 2 + (symbol.available ? symbol.alignment[1] * symbol.glyphHeight / 20 : 0)
        y: (parent.height - height) / 2 + (symbol.available ? symbol.alignment[2] * symbol.glyphHeight / 20 : 0)
        source: symbol.available ? "file://" + symbol.iconPath
            : symbol.themePath
        sourceSize.height: Math.ceil(height * 2)
        fillMode: Image.PreserveAspectFit
    }
    Text {
        anchors.centerIn: parent
        visible: !symbol.available && symbol.themePath === ""
        text: "BT"
        color: "white"
        font.pixelSize: 18
        font.bold: true
    }
}
