import QtQuick
import Quickshell.Services.UPower

QtObject {
    id: power
    property var devices: UPower.devices.values
    property bool batteryPowered: UPower.onBattery
    readonly property var battery: devices.find(device => device.isLaptopBattery && device.isPresent) || null
    readonly property bool laptop: battery !== null && battery.ready
    property bool initialized: false
    property bool previousOnBattery: false
    property int warningStage: 0
    signal chargingStarted(var device)
    signal batteryUpdated(var device)
    signal unplugged()
    signal batteryWarning(var device)

    function observeWarning() {
        if (!laptop || !batteryPowered || !Number.isFinite(battery.percentage)) { warningStage = 0; return; }
        const stage = battery.percentage <= 0.05 ? 2 : battery.percentage <= 0.20 ? 1 : 0;
        if (stage > warningStage) {
            const device = snapshot();
            device.dbusPath = "power/battery-warning/" + stage;
            device.kind = stage === 2 ? "battery-critical" : "battery-low";
            device.name = stage === 2 ? "Battery critical" : "Low battery";
            device.connected = true;
            batteryWarning(device);
        }
        warningStage = stage;
    }

    function snapshot() {
        return {
            dbusPath: "power/system-battery", name: "Charging", kind: "charging",
            transport: "Power", connected: !batteryPowered,
            batteryAvailable: laptop, battery: battery ? battery.percentage : NaN
        };
    }
    function observe() {
        if (!laptop) {
            if (initialized) unplugged();
            initialized = false;
            return;
        }
        if (!initialized) {
            previousOnBattery = batteryPowered;
            initialized = true;
            observeWarning();
            return;
        }
        const pluggedIn = previousOnBattery && !batteryPowered;
        const removed = !previousOnBattery && batteryPowered;
        previousOnBattery = batteryPowered;
        if (pluggedIn) chargingStarted(snapshot());
        if (removed) unplugged();
        observeWarning();
    }
    onLaptopChanged: observe()
    onBatteryPoweredChanged: observe()
    Component.onCompleted: observe()
    property Connections batteryMonitor: Connections {
        target: power.battery
        function onPercentageChanged() { power.batteryUpdated(power.snapshot()); power.observeWarning(); }
    }
}
