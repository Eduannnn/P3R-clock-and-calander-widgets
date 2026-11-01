import QtQuick
import Quickshell.Io

QtObject {
    id: notifications
    signal connectionChanged(var device, bool connected)
    property var eventProperties: ({})
    property var knownDevices: ({})

    function processEvent(properties) {
        if (properties.ACTION !== "add" && properties.ACTION !== "remove") return;
        const path = properties.DEVPATH || "";
        if (properties.ID_BUS !== "usb" && !/\/usb\d+\//.test(path)) return;
        const node = properties.DEVNAME || "";
        const model = properties.ID_MODEL_FROM_DATABASE || properties.ID_MODEL || "USB device";
        let kind = "";
        if (properties.SUBSYSTEM === "input" && /^\/dev\/input\/event\d+$/.test(node)) {
            if (properties.ID_INPUT_JOYSTICK === "1" || /controller|gamepad|dualsense|dualshock|xbox/i.test(model)) kind = "controller";
            else if (properties.ID_INPUT_KEYBOARD === "1") kind = "keyboard";
            else if (properties.ID_INPUT_MOUSE === "1") kind = "mouse";
        } else if (properties.SUBSYSTEM === "sound" && /\/sound\/card\d+$/.test(path)) {
            kind = /speaker/i.test(model) ? "speaker" : "headphones";
        }
        const connected = properties.ACTION === "add";
        const device = knownDevices[path] || (kind ? {
            name: model.replace(/_/g, " "),
            kind: kind,
            dbusPath: "usb:" + (properties.ID_SERIAL || properties.ID_PATH || path),
            icon: kind === "controller" ? "input-gaming" : kind === "headphones" ? "audio-headphones"
                : kind === "speaker" ? "audio-speakers" : "input-" + kind,
            transport: "USB"
        } : null);
        if (!device) return;
        if (connected) knownDevices[path] = device;
        else delete knownDevices[path];
        connectionChanged(device, connected);
    }

    function readLine(line) {
        if (line.trim() === "" || line.startsWith("UDEV ")) {
            processEvent(eventProperties);
            eventProperties = {};
            return;
        }
        const equals = line.indexOf("=");
        if (equals > 0) eventProperties[line.slice(0, equals)] = line.slice(equals + 1);
    }

    property Process monitor: Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--property", "--subsystem-match=input", "--subsystem-match=sound"]
        stdout: SplitParser { onRead: line => notifications.readLine(line) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 127) restartTimer.restart();
        }
    }
    property Timer restartTimer: Timer {
        interval: 3000
        onTriggered: notifications.monitor.running = true
    }
}
