import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../notch" as Notch

Column {
    id: networks
    property bool active: false
    property var entries: []
    property var selected: null
    property string message: ""
    property string submittedPassword: ""
    signal connectionChanged()
    spacing: 6

    function refresh(rescan) {
        if (scan.running) return;
        scan.command = ["nmcli", "--terse", "--escape", "yes", "--fields",
            "IN-USE,BSSID,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", rescan ? "yes" : "auto"];
        scan.running = true;
    }
    function fields(line) {
        const result = [];
        let value = "", escaped = false;
        for (const character of line) {
            if (escaped) { value += character; escaped = false; }
            else if (character === "\\") escaped = true;
            else if (character === ":") { result.push(value); value = ""; }
            else value += character;
        }
        result.push(value);
        return result;
    }
    function connectSelected() {
        if (!selected || connection.running) return;
        submittedPassword = password.text;
        password.clear();
        message = "Connecting to " + selected.name + "…";
        connection.stdinEnabled = submittedPassword !== "";
        connection.command = ["nmcli", "--wait", "30"].concat(submittedPassword ? ["--ask"] : [])
            .concat(["device", "wifi", "connect", selected.bssid]);
        connection.running = true;
    }
    onActiveChanged: {
        if (active) refresh(false);
        else { password.clear(); selected = null; }
    }
    Component.onCompleted: { if (active) refresh(false); }
    Process {
        id: scan
        environment: ({ LC_ALL: "C" })
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.trim().split("\n")) {
                    const row = networks.fields(line);
                    if (row.length !== 5 || !row[2]) continue;
                    const entry = { connected: row[0] === "*", bssid: row[1], name: row[2],
                        signal: Number(row[3]), security: row[4] };
                    const key = JSON.stringify([entry.name, entry.security]);
                    if (!found[key] || entry.connected || (!found[key].connected && entry.signal > found[key].signal)) found[key] = entry;
                }
                networks.entries = Object.values(found).sort((a, b) => Number(b.connected) - Number(a.connected) || b.signal - a.signal);
            }
        }
        stderr: StdioCollector {}
        onExited: code => { if (code !== 0) networks.message = "Couldn't refresh networks. Try again."; }
    }
    Process {
        id: connection
        environment: ({ LC_ALL: "C" })
        onStarted: {
            if (networks.submittedPassword) write(networks.submittedPassword + "\n");
            networks.submittedPassword = "";
            stdinEnabled = false;
        }
        // Don't log prompts or connection output, which can include private data.
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            networks.message = code === 0 ? "Connected." : "Couldn't connect. Check the password and try again.";
            if (code === 0) networks.selected = null;
            networks.refresh(false);
            networks.connectionChanged();
        }
    }
    Row {
        width: parent.width
        Text {
            width: parent.width - 80; height: 30
            verticalAlignment: Text.AlignVCenter
            text: scan.running ? "Finding networks…" : "Wi-Fi networks"
            color: "#aaaab2"; font.pixelSize: 12
        }
        Button {
            width: 80; height: 30
            enabled: !scan.running && !connection.running
            text: "Refresh"
            onClicked: networks.refresh(true)
            background: Rectangle { radius: 6; color: parent.hovered ? "#48484e" : "#38383e" }
            contentItem: Text { text: parent.text; color: "#f5f5f7"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
    ListView {
        width: parent.width
        height: Math.min(contentHeight, 180)
        model: networks.entries
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollIndicator.vertical: ScrollIndicator {}
        delegate: ItemDelegate {
            id: networkRow
            required property var modelData
            width: ListView.view.width; height: 36
            enabled: !connection.running
            onClicked: {
                if (modelData.connected) return;
                networks.selected = modelData;
                networks.message = "";
                password.clear();
                if (!modelData.security || modelData.security === "--") networks.connectSelected();
                else password.forceActiveFocus();
            }
            background: Rectangle { radius: 6; color: networkRow.hovered ? "#48484e" : "transparent" }
            contentItem: Item {
                Notch.SfSymbol {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 16; height: 16
                    symbolName: networkRow.modelData.connected ? "checkmark" : "wifi"
                    symbolColor: "white"; fallbackIcon: "network-wireless"
                }
                Text {
                    x: 25; width: parent.width - 110; anchors.verticalCenter: parent.verticalCenter
                    text: networkRow.modelData.name; elide: Text.ElideRight
                    color: "#f5f5f7"; font.pixelSize: 12
                }
                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: networkRow.modelData.connected ? "Connected" : networkRow.modelData.signal + "%"
                    color: "#aaaab2"; font.pixelSize: 11
                }
            }
        }
    }
    Text { visible: !scan.running && networks.entries.length === 0; text: "No networks found."; color: "#aaaab2"; font.pixelSize: 12 }
    Column {
        width: parent.width; spacing: 6
        visible: networks.selected !== null
        Text { width: parent.width; text: networks.selected ? networks.selected.name : ""; elide: Text.ElideRight; color: "white"; font.pixelSize: 12 }
        TextField {
            id: password
            width: parent.width; height: 34
            enabled: !connection.running
            echoMode: TextInput.Password
            placeholderText: "Password (leave blank to use saved credentials)"
            color: "white"; placeholderTextColor: "#aaaab2"
            font.pixelSize: 12
            background: Rectangle { radius: 6; color: "#38383e"; border.color: password.activeFocus ? "#6578ff" : "transparent" }
            onAccepted: networks.connectSelected()
        }
        Button {
            width: parent.width; height: 32
            enabled: !connection.running
            text: connection.running ? "Connecting…" : "Connect"
            onClicked: networks.connectSelected()
            background: Rectangle { radius: 6; color: parent.hovered ? "#48484e" : "#38383e" }
            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        }
    }
    Text { width: parent.width; visible: text !== ""; text: networks.message; wrapMode: Text.Wrap; color: "#aaaab2"; font.pixelSize: 11 }
}
