import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../notch" as Notch
import "../common/AudioLevel.js" as AudioLevel
import "../common" as Common

PanelWindow {
    id: center
    property bool opened: false
    Binding { target: Common.NotchPanels; property: "controlCenterVisible"; value: center.visible }
    Binding { target: Common.NotchPanels; property: "controlCenterLeft"; value: card.x }
    property real reveal: opened ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    property real topInset: 38
    property real notchCenterX: width / 2
    property real notchWidth: 208
    property real statusWidth: 50
    property real earRadius: 6
    property real batteryLevel: -1
    property string details: ""
    property bool wifiEnabled: false
    property string wifiName: "Not connected"
    property string message: ""
    property bool focusEnabled: false
    property bool idleEnabled: true
    property bool idleAvailable: false
    property int previousPowerProfile: PowerProfile.Balanced
    readonly property bool lowPower: PowerProfiles.profile === PowerProfile.PowerSaver
    property bool powerMenuOpen: false
    property string backlightPath: ""
    property real brightness: 0
    property real maximumBrightness: 0
    property int pendingBrightness: 1
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var player: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing)
        || Mpris.players.values.find(p => p.trackTitle !== "") || null
    readonly property var pairedDevices: Bluetooth.devices.values.filter(device => device.paired || device.connected)

    function toggle() { opened = !opened; }
    function performPowerAction(action) {
        const commands = {
            lock: [Quickshell.env("P3R_LOCK_COMMAND") || "hypr-session-lock"],
            logout: ["uwsm", "stop"],
            reboot: ["systemctl", "reboot"],
            shutdown: ["systemctl", "poweroff"]
        };
        if (!commands[action]) return;
        opened = false;
        Quickshell.execDetached(commands[action]);
    }
    function launch(args) {
        opened = false;
        Quickshell.execDetached(Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
            ? ["uwsm", "app", "--"].concat(args) : args);
    }
    function refreshWifi() {
        if (!radioQuery.running) radioQuery.running = true;
        if (!networkQuery.running) networkQuery.running = true;
    }
    function refreshFocus() { if (!focusQuery.running) focusQuery.running = true; }
    function refreshIdle() { if (!idleQuery.running) idleQuery.running = true; }
    function toggleIdle() {
        if (idleAction.running || !idleAvailable) return;
        idleAction.command = ["systemctl", "--user", idleEnabled ? "stop" : "start", "hypridle.service"];
        idleAction.running = true;
    }
    function toggleLowPower() {
        if (lowPower) PowerProfiles.profile = previousPowerProfile;
        else {
            previousPowerProfile = PowerProfiles.profile;
            PowerProfiles.profile = PowerProfile.PowerSaver;
        }
    }
    function toggleFocus() {
        if (focusAction.running) return;
        focusAction.command = ["makoctl", "mode", focusEnabled ? "-r" : "-a", "do-not-disturb"];
        focusAction.running = true;
    }
    onOpenedChanged: {
        if (opened) {
            details = "";
            powerMenuOpen = false;
            message = "";
            refreshWifi();
            refreshFocus();
            refreshIdle();
            backlightValue.reload();
            Qt.callLater(() => keyHandler.forceActiveFocus());
        }
    }

    // Keep the surface alive until its closing transition has finished.
    visible: opened || reveal > 0.001
    mask: Region { width: center.opened ? center.width : 0; height: center.opened ? center.height : 0 }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "p3r-control-center"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    PwObjectTracker { objects: center.sink ? [center.sink] : [] }
    Process {
        id: idleQuery
        command: ["systemctl", "--user", "show", "hypridle.service", "--property=LoadState,ActiveState"]
        stdout: StdioCollector {
            onStreamFinished: {
                const properties = text.trim().split("\n");
                center.idleAvailable = properties.includes("LoadState=loaded");
                center.idleEnabled = properties.includes("ActiveState=active");
            }
        }
    }
    Process {
        id: idleAction
        onExited: code => {
            center.refreshIdle();
            if (code !== 0) center.message = "Couldn't change automatic locking and sleep.";
        }
    }
    Process {
        id: focusQuery
        command: ["makoctl", "mode"]
        stdout: StdioCollector {
            onStreamFinished: center.focusEnabled = text.trim().split(/\s+/).includes("do-not-disturb")
        }
    }
    Process {
        id: focusAction
        onExited: (code, status) => {
            center.refreshFocus();
            if (code !== 0) center.message = "Couldn't change Do Not Disturb.";
        }
    }
    Process {
        id: radioQuery
        command: ["nmcli", "--terse", "--fields", "WIFI", "general"]
        stdout: StdioCollector { onStreamFinished: center.wifiEnabled = text.trim() === "enabled" }
    }
    Process {
        id: networkQuery
        command: ["nmcli", "--terse", "--escape", "no", "--fields", "IN-USE,SSID", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(line => line.startsWith("*:"));
                center.wifiName = line ? line.slice(2) : "Not connected";
            }
        }
    }
    Process {
        id: radioAction
        onExited: (code, status) => {
            center.refreshWifi();
            if (code !== 0) center.message = "Couldn't change Wi-Fi. Check network settings.";
        }
    }
    Process {
        running: true
        command: ["sh", "-c", 'for path in /sys/class/backlight/*; do if [ -r "$path/brightness" ]; then printf "%s" "$path"; break; fi; done']
        stdout: StdioCollector { onStreamFinished: center.backlightPath = text.trim() }
    }
    FileView {
        path: center.backlightPath ? center.backlightPath + "/max_brightness" : ""
        printErrors: false
        onLoaded: { center.maximumBrightness = Number(text()); backlightValue.reload(); }
    }
    FileView {
        id: backlightValue
        path: center.backlightPath ? center.backlightPath + "/brightness" : ""
        printErrors: false
        onLoaded: {
            if (center.maximumBrightness > 0 && !brightnessDelay.running && !brightnessAction.running)
                center.brightness = Number(text()) / center.maximumBrightness;
        }
    }
    Timer {
        interval: 1500; running: center.opened; repeat: true
        onTriggered: { center.refreshWifi(); center.refreshFocus(); center.refreshIdle(); backlightValue.reload(); }
    }
    Timer {
        id: brightnessDelay
        // Throttle writes to the latest value without waiting for dragging to stop.
        interval: 16
        onTriggered: {
            if (brightnessAction.running) { restart(); return; }
            brightnessAction.command = ["brightnessctl", "--device", center.backlightPath.split("/").pop(),
                "set", center.pendingBrightness + "%"];
            brightnessAction.running = true;
        }
    }
    Process {
        id: brightnessAction
        onExited: (code, status) => {
            if (code !== 0) center.message = "Couldn't change display brightness.";
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: center.opened = false
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: center.opened = false }

        Rectangle {
            id: card
            anchors { top: parent.top; topMargin: -(1 - center.reveal) * 8 }
            x: Math.max(8, Math.min(parent.width - width - 8, center.notchCenterX - width / 2))
            opacity: center.reveal
            scale: 0.98 + 0.02 * center.reveal
            transformOrigin: Item.TopRight
            width: Math.min(680, parent.width - 24)
            height: Math.min(content.implicitHeight + center.topInset + 18, parent.height - y - 16)
            radius: 14
            topLeftRadius: 0
            topRightRadius: 0
            color: "black"
            Notch.TopEdgeEars { width: parent.width; radius: center.earRadius }
            // Consume empty card clicks beneath the interactive header controls.
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
            ConnectionIndicator {
                id: headerIndicator
                x: 12
                y: (center.topInset - height) / 2 - 2
                width: 32; height: 32
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: center.toggle()
                }
            }
            Text {
                x: headerIndicator.x + headerIndicator.width + 8
                y: (center.topInset - height) / 2 - 2
                width: Math.max(0, center.notchCenterX - center.notchWidth / 2 - card.x - x - 8)
                text: center.batteryLevel >= 0 ? "Battery  ·  " + Math.round(center.batteryLevel * 100) + "%" : ""
                color: "#f5f5f7"
                font { pixelSize: 11; weight: Font.DemiBold }
                elide: Text.ElideRight
            }
            ToolButton {
                x: card.width - width - 12
                y: (center.topInset - height) / 2 - 2
                width: 26; height: 26
                background: Rectangle { radius: 7; color: parent.hovered || center.powerMenuOpen ? "#38383e" : "transparent" }
                contentItem: Notch.SfSymbol { symbolName: "power"; symbolColor: "#f5f5f7"; fallbackIcon: "system-shutdown" }
                padding: 5
                onClicked: center.powerMenuOpen = !center.powerMenuOpen
                ToolTip.visible: hovered
                ToolTip.text: "Power options"
                Accessible.name: "Power options"
            }
            Flickable {
                anchors { fill: parent; margins: 10; topMargin: center.topInset + 8 }
                contentHeight: content.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: content
                    width: parent.width
                    spacing: 8
                    PowerMenu {
                        width: parent.width
                        visible: center.powerMenuOpen
                        onActionRequested: action => center.performPowerAction(action)
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        Column {
                            width: (parent.width - parent.spacing) / 2
                            spacing: 8
                            Row {
                                id: connectivityTiles
                                width: parent.width; spacing: 8
                                ConnectivityTile {
                                    width: (parent.width - parent.spacing) / 2
                                    title: "Wi-Fi"; symbol: "wifi"; fallbackIcon: "network-wireless"
                                    active: center.wifiEnabled
                                    available: !radioAction.running
                                    subtitle: active ? center.wifiName : "Off"
                                    onToggled: {
                                        radioAction.command = ["nmcli", "radio", "wifi", center.wifiEnabled ? "off" : "on"];
                                        radioAction.running = true;
                                    }
                                    onDetailsRequested: center.details = center.details === "wifi" ? "" : "wifi"
                                }
                                ConnectivityTile {
                                    width: (parent.width - parent.spacing) / 2
                                    title: "Bluetooth"; symbol: "bluetooth"; fallbackIcon: "bluetooth"
                                    active: center.adapter !== null && center.adapter.enabled
                                    available: center.adapter !== null
                                    subtitle: !available ? "Unavailable" : !active ? "Off"
                                        : Bluetooth.devices.values.filter(device => device.connected).length + " connected"
                                    onToggled: { if (center.adapter) center.adapter.enabled = !center.adapter.enabled; }
                                    onDetailsRequested: center.details = center.details === "bluetooth" ? "" : "bluetooth"
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: 8
                                Column {
                                    width: parent.width - 104 - parent.spacing
                                    spacing: 8
                                    ControlToggle {
                                        width: parent.width
                                        title: "Focus"
                                        subtitle: center.focusEnabled ? "Do Not Disturb" : "Off"
                                        symbol: "moon.fill"; fallbackIcon: "notifications-disabled"
                                        accent: "#7961bb"
                                        active: center.focusEnabled
                                        available: !focusAction.running
                                        onToggled: center.toggleFocus()
                                    }
                                    ControlToggle {
                                        width: parent.width
                                        title: "Keep Awake"
                                        subtitle: center.idleEnabled ? "Normal lock & sleep" : "Lock & sleep paused"
                                        symbol: center.idleEnabled ? "lock.fill" : "cup.and.saucer.fill"
                                        fallbackIcon: "system-lock-screen"
                                        active: !center.idleEnabled
                                        available: center.idleAvailable && !idleAction.running
                                        onToggled: center.toggleIdle()
                                    }
                                }
                                Rectangle {
                                    width: 104; height: 104; radius: 10
                                    color: center.lowPower ? "#78631b" : lowPowerPointer.containsMouse ? "#36363c" : "#27272b"
                                    Notch.SfSymbol {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
                                        width: 24; height: 24
                                        symbolName: "battery.100percent"
                                        symbolColor: center.lowPower ? "#ffe17a" : "#aaaab2"
                                        fallbackIcon: "battery-full"
                                    }
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 56 }
                                        text: "Low Power"; color: "#f5f5f7"
                                        font { pixelSize: 10; weight: Font.DemiBold }
                                    }
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 72 }
                                        text: center.lowPower ? "On" : "Off"; color: "#aaaab2"; font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: lowPowerPointer
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: center.toggleLowPower()
                                    }
                                    Accessible.name: "Low Power Mode"
                                    Accessible.role: Accessible.CheckBox
                                    Accessible.checkable: true
                                    Accessible.checked: center.lowPower
                                }
                            }
                        }
                        Column {
                            id: audioDisplayControls
                            width: (parent.width - parent.spacing) / 2
                            spacing: 8
                            ControlSlider {
                                width: parent.width
                                height: connectivityTiles.height
                                label: "Display"; symbol: "sun.max.fill"
                                value: center.brightness
                                available: center.maximumBrightness > 0
                                onAdjusted: level => {
                                    center.brightness = level;
                                    center.pendingBrightness = Math.max(1, Math.round(level * 100));
                                    if (!brightnessDelay.running) brightnessDelay.start();
                                }
                            }
                            Rectangle {
                                width: parent.width
                                height: 104
                                radius: 10
                                color: "#27272b"
                                ControlSlider {
                                    width: parent.width
                                    label: "Sound"
                                    color: "transparent"
                                    symbol: center.sink && center.sink.audio && center.sink.audio.muted ? "speaker.slash.fill" : "speaker.wave.3.fill"
                                    value: center.sink && center.sink.audio ? Math.min(1, center.sink.audio.volume) : 0
                                    available: !!(center.sink && center.sink.audio)
                                    onAdjusted: level => {
                                        if (center.sink && center.sink.audio) {
                                            center.sink.audio.volume = AudioLevel.sliderLevel(level);
                                            center.sink.audio.muted = false;
                                        }
                                    }
                                    onIconClicked: { if (center.sink && center.sink.audio) center.sink.audio.muted = !center.sink.audio.muted; }
                                }
                                AudioOutputSelector {
                                    x: 10; y: 64
                                    width: parent.width - 20
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: connectivity.implicitHeight + 16
                        visible: center.details !== ""
                        radius: 10; color: "#27272b"
                        Column {
                            id: connectivity
                            x: 8; y: 8; width: parent.width - 16; spacing: 4
                            WifiNetworks {
                                width: parent.width
                                visible: center.details === "wifi"
                                active: visible && center.opened && center.wifiEnabled
                                onConnectionChanged: center.refreshWifi()
                            }
                            Text {
                                visible: center.details === "bluetooth"
                                x: 4
                                text: center.details === "wifi" ? (center.wifiEnabled ? center.wifiName : "Wi-Fi is off") : "Saved devices"
                                width: parent.width - 8; elide: Text.ElideRight
                                color: "#aaaab2"; font { pixelSize: 12; weight: Font.DemiBold }
                            }
                            Repeater {
                                model: center.details === "bluetooth" ? center.pairedDevices : []
                                delegate: ItemDelegate {
                                    required property var modelData
                                    width: connectivity.width
                                    height: 34
                                    text: modelData.name + (modelData.connected ? " · Connected" : "")
                                    onClicked: { if (modelData.connected) modelData.disconnect(); else modelData.connect(); }
                                    contentItem: Text { text: parent.text; color: "#f5f5f7"; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 }
                                }
                            }
                            Button {
                                visible: center.details === "bluetooth"
                                width: parent.width; height: 34
                                text: "Pair / manage devices…"
                                background: Rectangle { radius: 8; color: parent.hovered ? "#48484e" : "#38383e" }
                                contentItem: Text { text: parent.text; color: "#f5f5f7"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: center.launch(["blueman-manager"])
                            }
                        }
                    }
                    Rectangle {
                        visible: center.player !== null && center.player.playbackState === MprisPlaybackState.Playing
                        width: parent.width; height: 60; radius: 10; color: "#27272b"
                        Image { x: 8; y: 8; width: 44; height: 44; source: center.player ? center.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop }
                        Column {
                            x: 60; y: 12; width: parent.width - 136; spacing: 4
                            Text { width: parent.width; text: center.player ? center.player.trackTitle || "Media" : "Nothing playing"; color: "#f5f5f7"; font { pixelSize: 12; weight: Font.DemiBold } elide: Text.ElideRight }
                            Text { width: parent.width; text: center.player ? center.player.trackArtist : ""; color: "#aaaab2"; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Repeater {
                                model: ["play", "next"]
                                delegate: Item {
                                    required property string modelData
                                    width: 30; height: 34
                                    Notch.SfSymbol {
                                        anchors.centerIn: parent; width: 18; height: 18
                                        symbolName: modelData === "next" ? "forward.end.fill"
                                            : center.player && center.player.playbackState === MprisPlaybackState.Playing ? "pause.fill" : "play.fill"
                                        symbolColor: "#f5f5f7"
                                        fallbackIcon: modelData === "next" ? "media-skip-forward" : "media-playback-start"
                                        opacity: center.player ? 1 : 0.35
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: center.player !== null && (modelData === "next" ? center.player.canGoNext : center.player.canTogglePlaying)
                                        onClicked: { if (modelData === "next") center.player.next(); else center.player.togglePlaying(); }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: center.message !== ""
                        width: parent.width; wrapMode: Text.Wrap
                        text: center.message; color: "#a92f32"; font.pixelSize: 12
                    }
                }
            }
        }
    }
}
