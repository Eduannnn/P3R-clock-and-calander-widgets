import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: state
    property bool enabled: false
    property rect clockRect: Qt.rect(0, 0, 0, 0)
    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "")
        + "/hypr/" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") + "/.socket.sock"

    // Read raw JSON so geometry/workspace detection also works with Hyprland
    // 0.57's workspace objects. No shell commands or subprocess polling.
    component Query: Socket {
        id: query
        required property string request
        property var result: []
        property bool pending: false
        property double requestedAt: 0
        function refresh() {
            if (pending) {
                if (Date.now() - requestedAt > 1000) { connected = false; pending = false; }
                return;
            }
            pending = true;
            requestedAt = Date.now();
            connected = true;
        }
        onConnectedChanged: {
            if (connected) { write(request); flush(); }
        }
        onError: { pending = false; }
        parser: StdioCollector {
            waitForEnd: false
            onTextChanged: {
                try {
                    const value = JSON.parse(text);
                    if (Array.isArray(value)) {
                        query.result = value;
                        query.connected = false;
                    }
                } catch (error) { return; } // Wait for the rest of a split reply.
            }
            onStreamFinished: {
                query.pending = false;
            }
        }
    }

    property Query clients: Query { path: state.socketPath; request: "j/clients" }
    property Query outputs: Query { path: state.socketPath; request: "j/monitors" }
    property Timer refresh: Timer {
        interval: 150
        running: state.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: { state.clients.refresh(); state.outputs.refresh(); }
    }

    readonly property bool compact: enabled && clients.result.some(window => {
        if (!window.mapped || window.hidden || window.minimized
            || !Array.isArray(window.at) || !Array.isArray(window.size)) return false;
        const visible = window.pinned || outputs.result.some(output =>
            (output.activeWorkspace && output.activeWorkspace.id === window.workspace?.id)
            || (output.specialWorkspace && output.specialWorkspace.id !== 0
                && output.specialWorkspace.id === window.workspace?.id));
        return visible && window.at[0] < clockRect.x + clockRect.width
            && window.at[0] + window.size[0] > clockRect.x
            && window.at[1] < clockRect.y + clockRect.height
            && window.at[1] + window.size[1] > clockRect.y;
    })
}
