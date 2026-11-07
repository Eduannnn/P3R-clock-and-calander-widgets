import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../notch" as Notch

Item {
    id: indicator
    implicitWidth: 32
    implicitHeight: 32
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: 0.8
        shadowBlur: 0.5
        shadowVerticalOffset: 1
        shadowHorizontalOffset: 0
    }
    property bool wifiConnected: false
    property int wifiSignal: 0
    property bool iphoneTethered: false
    readonly property var battery: UPower.devices.values.find(device => device.isLaptopBattery && device.isPresent) || null
    readonly property real batteryLevel: battery && battery.ready ? Math.max(0, Math.min(1, battery.percentage)) : -1
    readonly property color ringColor: PowerProfiles.profile === PowerProfile.PowerSaver ? "#ffd60a" : "white"

    Canvas {
        id: ring
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: indicator
            function onBatteryLevelChanged() { ring.requestPaint(); }
            function onRingColorChanged() { ring.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (indicator.batteryLevel < 0) return;
            const radius = Math.min(width, height) / 2 - 2;
            const start = Math.PI * 0.75, span = Math.PI * 1.5;
            ctx.lineWidth = 2.5;
            ctx.lineCap = "round";
            ctx.strokeStyle = "#55ffffff";
            ctx.beginPath(); ctx.arc(width / 2, height / 2, radius, start, start + span); ctx.stroke();
            if (indicator.batteryLevel > 0) {
                ctx.strokeStyle = indicator.ringColor;
                ctx.beginPath(); ctx.arc(width / 2, height / 2, radius, start, start + span * indicator.batteryLevel); ctx.stroke();
            }
        }
    }
    Notch.SfSymbol {
        anchors.centerIn: parent
        width: parent.width * 0.55
        height: parent.height * 0.55
        symbolName: indicator.iphoneTethered ? "personalhotspot" : indicator.wifiConnected ? "wifi" : "wifi.slash"
        symbolColor: "white"
        fallbackIcon: indicator.iphoneTethered ? "network-wired" : indicator.wifiConnected ? "network-wireless-connected" : "network-wireless-offline"
    }
    Process {
        id: wifiQuery
        running: indicator.visible
        command: ["sh", Qt.resolvedUrl("connection-status.sh").toString().replace(/^file:\/\//, "").replace(/^qs:/, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const active = lines.find(line => line.startsWith("wifi:"));
                indicator.wifiConnected = active !== undefined;
                indicator.wifiSignal = active ? Number(active.slice(5)) : 0;
                indicator.iphoneTethered = lines.includes("iphone:true");
            }
        }
    }
    Timer {
        interval: 5000
        repeat: true
        running: indicator.visible
        onTriggered: { if (!wifiQuery.running) wifiQuery.running = true; }
    }
}
