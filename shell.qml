// Combined widget launcher with explicit source watching.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    // Each widget folder provides shell.qml. Keep references for the shell's lifetime.
    property var widgets: ({})
    property var watchedFiles: ({})
    // Session launchers can leave unreviewed widgets disabled without editing
    // their appearance or maintaining another copy of the shell.
    readonly property var disabledWidgets: (Quickshell.env("P3R_WIDGETS_DISABLE") || "")
        .split(",").map(name => name.trim().toLowerCase()).filter(name => name.length > 0)

    Timer {
        id: sourceReload
        interval: 250
        onTriggered: Quickshell.reload(false)
    }
    Component {
        id: watcherFactory
        FileView {
            watchChanges: true
            onFileChanged: {
                console.log("Widget source changed: " + path);
                sourceReload.restart();
            }
        }
    }
    Process {
        running: true
        // Resolve symlinks so edits to the original files are observed too.
        command: ["find", "-L", Quickshell.shellDir, "-mindepth", "2", "-maxdepth", "3",
            "-type", "f", "(", "-name", "*.qml", "-o", "-name", "*.js", "-o", "-name", "qmldir", ")",
            "-exec", "readlink", "-f", "{}", ";"]
        stdout: SplitParser {
            onRead: path => {
                if (path.length > 0 && !root.watchedFiles[path])
                    root.watchedFiles[path] = watcherFactory.createObject(root, { path: path });
            }
        }
        stderr: SplitParser { onRead: message => console.error("Widget source discovery: " + message) }
    }


    function loadWidget(path) {
        const widgetName = path.split("/").slice(-2)[0];
        if (disabledWidgets.indexOf(widgetName) >= 0) {
            console.log("Widget disabled for this session: " + widgetName);
            return;
        }
        if (widgets[path]) return;
        const component = Qt.createComponent(Qt.resolvedUrl(path), Component.PreferSynchronous, root);
        function finish() {
            if (component.status === Component.Loading) return;
            if (component.status === Component.Error) {
                console.error("Widget failed to load: " + path + "\n" + component.errorString());
                return;
            }
            const widget = component.createObject(root);
            if (widget === null) {
                console.error("Widget failed to start: " + path + "\n" + component.errorString());
                return;
            }
            widgets[path] = widget;
            console.log("Loaded widget: " + path);
        }
        if (component.status === Component.Loading) component.statusChanged.connect(finish);
        else finish();
    }

    Process {
        running: true
        // A fixed script with a separate path argument also handles spaces safely.
        command: ["sh", "-c",
            'if [ -f "$1/taskbar/shell.qml" ]; then printf "%s\\n" "$1/taskbar/shell.qml"; fi; for entry in "$1"/*/shell.qml; do if [ -f "$entry" ] && [ "$entry" != "$1/taskbar/shell.qml" ]; then printf "%s\\n" "$entry"; fi; done',
            "widget-discovery", Quickshell.shellDir]
        stdout: SplitParser {
            onRead: path => { if (path.length > 0) root.loadWidget(path); }
        }
        stderr: SplitParser { onRead: message => console.error("Widget discovery: " + message) }
    }
}
