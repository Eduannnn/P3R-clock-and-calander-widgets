import QtQuick
import QtQml.Models
import Quickshell.Bluetooth

QtObject {
    id: notifications

    property var devices: Bluetooth.devices.values
    property int displayMs: 4000
    property int startupMs: 1000
    property bool ready: false
    property var current: null
    property var queue: []

    function deviceKind(device) {
        const description = ((device.icon || "") + " " + (device.name || "")
            + " " + (device.deviceName || "")).toLowerCase();
        if (/gaming|gamepad|controller|dualsense|dualshock|xbox|joy-con/.test(description)) return "controller";
        if (/airpods.?max/.test(description)) return "headphones";
        if (/earbud|airpod|galaxy buds|pixel buds/.test(description)) return "earbuds";
        if (/headphone|headset/.test(description)) return "headphones";
        if (/keyboard/.test(description)) return "keyboard";
        if (/mouse|pointing/.test(description)) return "mouse";
        if (/speaker|audio-card/.test(description)) return "speaker";
        if (/phone/.test(description)) return "phone";
        return "bluetooth";
    }

    function enqueue(device, connected) {
        const event = {
            key: device.dbusPath || device.address || device.name,
            name: device.name || device.deviceName || "Bluetooth device",
            kind: device.kind || deviceKind(device),
            icon: device.icon || "bluetooth",
            transport: device.transport || "Bluetooth",
            connected: connected,
            battery: batteryLevel(device, connected)
        };
        const last = queue.length > 0 ? queue[queue.length - 1] : current;
        if (last && last.key === event.key && last.connected === event.connected) return;
        if (current === null) {
            current = event;
            dismissTimer.restart();
        } else {
            queue = queue.concat([event]).slice(-8);
        }
    }

    function batteryLevel(device, connected) {
        const value = device.battery;
        return connected && device.batteryAvailable === true && typeof value === "number"
            && Number.isFinite(value) && value >= 0 && value <= 1 ? value : null;
    }

    // BlueZ often publishes the battery after the connection notification starts.
    function updateBattery(device) {
        const key = device.dbusPath || device.address || device.name;
        const level = batteryLevel(device, device.connected);
        if (current !== null && current.key === key)
            current = Object.assign({}, current, { battery: current.connected ? level : null });
        queue = queue.map(event => event.key === key
            ? Object.assign({}, event, { battery: event.connected ? level : null }) : event);
    }

    function advance() {
        current = queue.length > 0 ? queue[0] : null;
        queue = queue.slice(1);
        if (current !== null) dismissTimer.restart();
    }

    property Timer dismissTimer: Timer {
        interval: notifications.displayMs
        onTriggered: notifications.advance()
    }
    property Timer startupTimer: Timer {
        interval: notifications.startupMs
        running: true
        onTriggered: notifications.ready = true
    }
    property Instantiator observers: Instantiator {
        model: notifications.devices
        delegate: QtObject {
            id: observer
            required property var modelData
            property bool previousConnected: false
            Component.onCompleted: {
                previousConnected = modelData.connected;
                if (notifications.ready && previousConnected)
                    notifications.enqueue(modelData, true);
            }
            property Connections monitor: Connections {
                target: observer.modelData
                function onConnectedChanged() {
                    const connected = observer.modelData.connected;
                    if (connected === observer.previousConnected) return;
                    observer.previousConnected = connected;
                    if (notifications.ready) notifications.enqueue(observer.modelData, connected);
                }
                function onBatteryChanged() { notifications.updateBattery(observer.modelData); }
                function onBatteryAvailableChanged() { notifications.updateBattery(observer.modelData); }
            }
        }
    }
}
