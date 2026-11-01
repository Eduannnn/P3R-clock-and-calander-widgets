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
    signal chargingStarted(var device)
    signal batteryUpdated(var device)
    signal unplugged()

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
            return;
        }
        const pluggedIn = previousOnBattery && !batteryPowered;
        const removed = !previousOnBattery && batteryPowered;
        previousOnBattery = batteryPowered;
        if (pluggedIn) chargingStarted(snapshot());
        if (removed) unplugged();
    }
    onLaptopChanged: observe()
    onBatteryPoweredChanged: observe()
    Component.onCompleted: observe()
    property Connections batteryMonitor: Connections {
        target: power.battery
        function onPercentageChanged() { power.batteryUpdated(power.snapshot()); }
    }
}
