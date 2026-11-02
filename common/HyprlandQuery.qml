import QtQuick
import Quickshell
import Quickshell.Io

Socket {
    id: query
    required property string request
    property var result: []
    property bool pending: false
    property bool refreshQueued: false
    property double requestedAt: 0
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/hypr/"
        + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") + "/.socket.sock"
    function refresh() {
        if (pending) {
            refreshQueued = true;
            if (Date.now() - requestedAt > 1000) { connected = false; pending = false; }
            return;
        }
        pending = true;
        requestedAt = Date.now();
        connected = true;
    }
    onConnectedChanged: { if (connected) { write(request); flush(); } }
    onError: { pending = false; refreshQueued = false; }
    parser: StdioCollector {
        waitForEnd: false
        onTextChanged: {
            try {
                const data = JSON.parse(text);
                if (Array.isArray(data)) {
                    if (JSON.stringify(data) !== JSON.stringify(query.result)) query.result = data;
                    query.connected = false;
                }
            } catch (error) { /* Wait for a complete JSON reply. */ }
        }
        onStreamFinished: {
            query.pending = false;
            if (query.refreshQueued) {
                query.refreshQueued = false;
                Qt.callLater(query.refresh);
            }
        }
    }
}
