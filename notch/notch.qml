// Media controls, device notifications, and laptop charging in the MacBook notch.
// Run with:  quickshell -p notch.qml

import QtQuick
import "."
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io
import "../indicator" as Indicator
import "../common" as Common

ShellRoot {
    id: root
    property Item embeddedParent: null
    property var embeddedScreen: null
    property bool lockScreenMode: false
    signal lockControlsClosed()
    readonly property var activeControlCenter: root.lockScreenMode
        ? lockControlCenterLoader.item : controlCenterLoader.item
    readonly property real statusWidth: 50
    readonly property bool controlCenterOpen: activeControlCenter !== null && activeControlCenter.visible
    readonly property bool panelOpen: controlCenterOpen || (!lockScreenMode && Common.NotchPanels.overviewVisible)
    readonly property bool mediaDetached: panelOpen && shown && playing && !lockScreenMode
    readonly property bool overviewTransition: !lockScreenMode && !controlCenterOpen
        && Common.NotchPanels.overviewVisible
    // Mission Control owns a continuous gesture/spring timeline. The cover
    // follows its full progress, so returning begins as soon as it closes.
    // Control Center retains its existing independent spring unchanged.
    property real mediaDetachProgress: mediaDetached && !overviewTransition ? 1 : 0
    readonly property real mediaDetachFraction: overviewTransition
        ? (mediaDetached ? Math.max(0, Math.min(1, Common.NotchPanels.overviewProgress)) : 0)
        : Math.max(0, Math.min(1, mediaDetachProgress))
    Behavior on mediaDetachProgress {
        MotionSpring { responseMs: root.animMs; epsilon: 0.001 }
    }
    property real mediaBubbleLeft: 0
    onMediaDetachedChanged: { if (mediaDetached) mediaBubbleLeft = Common.NotchPanels.left; }
    Connections {
        target: Common.NotchPanels
        function onLeftChanged() { if (root.mediaDetached) root.mediaBubbleLeft = Common.NotchPanels.left; }
    }
    // The connectivity indicator yields its attached slot to the current
    // activity: music, OSDs, Bluetooth/USB notices and battery notifications.
    readonly property bool statusDetached: (shown || notificationActive) && !panelOpen
    readonly property real attachedStatusWidth: statusDetached ? 0 : statusWidth
    property real detachedStatusGap: 8
    property real statusDetachProgress: statusDetached ? 1 : 0
    readonly property real statusDetachFraction: Math.max(0, Math.min(1, statusDetachProgress))
    Behavior on statusDetachProgress {
        MotionSpring { responseMs: root.animMs; epsilon: 0.001 }
    }
    readonly property bool statusOnly: panelOpen || (!shown && !notificationActive)
    // Mission Control draws the indicator above its full-screen surface, but
    // follows this same animated icon rather than snapping to a second slot.
    Binding { target: Common.NotchPanels; property: "indicatorX"; value: statusIndicator.x; when: !root.lockScreenMode }
    Binding { target: Common.NotchPanels; property: "indicatorY"; value: statusIndicator.y; when: !root.lockScreenMode }
    Binding { target: Common.NotchPanels; property: "indicatorSize"; value: statusIndicator.width; when: !root.lockScreenMode }
    LazyLoader {
        id: controlCenterLoader
        active: !root.lockScreenMode
        component: Indicator.ControlCenter {
            screen: root.pickScreen()
            topInset: root.notchHeight
            notchCenterX: (root.cameraLeft + root.cameraRight) / 2
            notchWidth: root.notchWidth
            statusWidth: root.statusWidth
            earRadius: root.screenJoinRadius
            batteryLevel: statusIndicator.batteryLevel
        }
    }
    LazyLoader {
        id: lockControlCenterLoader
        active: root.lockScreenMode && root.embeddedParent !== null
        component: Indicator.LockPowerCenter {
            parent: root.embeddedParent
            topInset: root.notchHeight
            notchCenterX: (root.cameraLeft + root.cameraRight) / 2
            earRadius: root.screenJoinRadius
            notchWidth: root.notchWidth
            statusWidth: root.statusWidth
            onClosed: root.lockControlsClosed()
        }
    }
    IpcHandler {
        target: "controlCenter"
        function toggle(): void { if (root.activeControlCenter) root.activeControlCenter.toggle(); }
        function close(): void { if (root.activeControlCenter) root.activeControlCenter.opened = false; }
        function status(): string {
            const center = root.activeControlCenter;
            return JSON.stringify({ opened: center ? center.opened : false,
                visible: center ? center.visible : false, reveal: center ? center.reveal : 0,
                volume: center && center.sink && center.sink.audio ? center.sink.audio.volume : null });
        }
    }

    // ---------- notch calibration ----------
    property real notchWidth: cutout.valid ? cutout.rect.width : 280
    property real notchHeight: cutout.valid ? cutout.rect.height : 37
    property bool debugNotch: false
    property string screenName: "eDP-1"
    NotchCalibration { id: cutout; screen: root.pickScreen() }
    CalibrationOverlay { id: calibrationOverlay; store: cutout }
    Timer {
        interval: 300
        running: cutout.ready && !root.lockScreenMode
        onTriggered: {
            if (!cutout.valid && !calibrationOverlay.active) calibrationOverlay.open();
        }
    }
    readonly property real cameraLeft: cutout.valid ? cutout.rect.x : (pickScreen().width - notchWidth) / 2
    readonly property real cameraRight: cameraLeft + notchWidth
    readonly property real safeCompactOffset: cutout.valid
        ? Math.max(0, cutout.rect.y + cutout.rect.height + cutout.padding - notchHeight) : 0
    readonly property real safeExpandedOffset: cutout.valid
        ? Math.max(0, cutout.rect.y + cutout.rect.height + cutout.padding - 37 * uiScale) : 0
    readonly property real safeMediaLeftExtra: cutout.valid ? Math.max(0,
        cameraLeft - wingWidth + collapsedLeftInset
            - (cutout.rect.x - cutout.padding - 36)) : 0
    readonly property real safeMediaRightExtra: cutout.valid ? Math.max(0,
        cutout.rect.x + cutout.rect.width + cutout.padding + barCount * 3 + (barCount - 1) * 3 + 14
            - (cameraRight + wingWidth)) : 0
    readonly property real safeNoticeLeftExtra: cutout.valid ? Math.max(0,
        cameraLeft - notificationWingWidth + notificationLeftInset
            - (cutout.rect.x - cutout.padding - 44)) : 0

    // ---------- look & behaviour ----------
    property real   wingWidth: 20
    property real   collapsedLeftInset: 14
    property real   uiScale: 0.58            // expanded player scale
    property real   expandedWidth: 688 * uiScale
    property real   expandedHeight: 334 * uiScale
    property real   compactWidth: Math.max(notchWidth + 80, expandedWidth * 0.94)
    property int    compactPadding: 14
    property real   compactHeight: notchHeight + 40 + compactPadding
    property real   collapsedRadius: 12
    property real   expandedRadius: 70 * uiScale
    property real   earRadius: 16  // the concave corners where the notch meets the top of the screen
    property real   screenJoinRadius: 6
    property color  accent: "#49fffe"        // Persona cyan accent (used when the cover has no usable colour)
    property bool   tintFromCover: true      // progress bar + waveform take the cover art's main colour
    property color  dim: "#9aa0b4"           // Secondary text
    property string fontFamily: "sans-serif"
    property int    animMs: 250              // Spring response tempo, not a fixed settling duration
    property int    entranceMs: 360          // Gentler side-content reveal when media first starts
    property int    pausedLingerMs: 12000
    property int    trackPeekMs: 3500
    property int    collapseDelayMs: 350
    property int    bluetoothNoticeMs: 4000
    property bool   debugNotifications: false // repeat the existing notification preview
    onDebugNotificationsChanged: {
        if (debugNotifications) return;
        bluetoothNotifications.queue = bluetoothNotifications.queue.filter(event => !event.key.startsWith("preview/"));
        if (bluetoothNotifications.current && bluetoothNotifications.current.key.startsWith("preview/"))
            bluetoothNotifications.advance();
    }
    property real   notificationWingWidth: 44
    property real   notificationRightInset: 40.5
    property real   notificationLeftInset: 32
    property real   notificationBatteryWingWidth: 44
    readonly property var notificationBattery: bluetoothNotifications.current
        ? bluetoothNotifications.current.battery : null
    readonly property bool notificationHasBattery: typeof notificationBattery === "number"
        && Number.isFinite(notificationBattery) && notificationBattery >= 0 && notificationBattery <= 1
    // The physical cutout supplies the black center. Hide the empty trailing
    // edge inside its rounded corner instead of drawing a safety-padding lip.
    readonly property real notificationRightExtent: notificationHasBattery ? notificationBatteryWingWidth
        : cutout.valid ? -cutout.rect.cornerRadius : -notificationRightInset
    readonly property bool chargingNotice: bluetoothNotifications.current !== null
        && ["charging", "battery-low", "battery-critical"].includes(bluetoothNotifications.current.kind) && !systemOsd.active
    readonly property string powerNoticeLabel: !bluetoothNotifications.current ? "Charging"
        : bluetoothNotifications.current.kind === "battery-low" ? "Low battery"
        : bluetoothNotifications.current.kind === "battery-critical" ? "Battery critical" : "Charging"
    readonly property color powerNoticeColor: !bluetoothNotifications.current || bluetoothNotifications.current.kind === "charging"
        ? "#30df74" : bluetoothNotifications.current.kind === "battery-critical" ? "#ff654f" : "#ffbd59"
    readonly property real osdLeftWidth: 44 + cutout.padding
    readonly property real osdRightWidth: 55 + 8 + Math.ceil(osdLabelMetrics.advanceWidth) + 20 + cutout.padding
    TextMetrics {
        id: osdLabelMetrics
        text: systemOsd.label
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }
    SystemOsd { id: systemOsd }
    readonly property string chargingPercentage: notificationHasBattery ? Math.round(notificationBattery * 100) + "%" : ""
    readonly property real chargingLeftWidth: Math.ceil(chargingLabelMetrics.advanceWidth) + 14 + cutout.padding
    readonly property real chargingRightWidth: (notificationHasBattery ? Math.ceil(chargingPercentMetrics.advanceWidth) + 8 : 0)
        + 32 + 14 + cutout.padding
    TextMetrics {
        id: chargingLabelMetrics
        text: root.powerNoticeLabel
        font.family: root.fontFamily
        font.pixelSize: 16
        font.weight: Font.Medium
    }
    TextMetrics {
        id: chargingPercentMetrics
        text: root.chargingPercentage
        font.family: root.fontFamily
        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    BluetoothNotifications {
        id: bluetoothNotifications
        displayMs: root.bluetoothNoticeMs
        hold: systemOsd.active
    }
    UsbNotifications {
        id: usbNotifications
        onConnectionChanged: (device, connected) => bluetoothNotifications.enqueue(device, connected)
    }
    PowerNotifications {
        id: powerNotifications
        onChargingStarted: device => bluetoothNotifications.enqueue(device, true)
        onBatteryUpdated: device => bluetoothNotifications.updateBattery(device)
        onUnplugged: bluetoothNotifications.dismiss("power/system-battery")
        onBatteryWarning: device => bluetoothNotifications.enqueue(device, true)
    }
    IpcHandler {
        id: notchIpc
        target: "notch"
        function calibrate(): void { if (!root.lockScreenMode) calibrationOverlay.open(); }
        function hideCalibration(): void { calibrationOverlay.close(); }
        function showOsd(kind: string, level: real, muted: bool): void { systemOsd.show(kind, level, muted); }
        function mediaInteractionStatus(): string {
            const origin = progress.mapToItem(root.embeddedParent || win.contentItem, 0, 0);
            return JSON.stringify({ shown: root.shown, expanded: root.expanded,
                hovering: root.hovering, scrubbing: root.scrubbing,
                progressHovered: seekArea.containsMouse,
                x: notch.x, y: notch.y, width: notch.width, height: notch.height,
                progressX: origin.x + progress.width / 2,
                progressY: origin.y + progress.height / 2 });
        }
        function previewCharging(): void {
            if (!powerNotifications.laptop) return;
            const device = powerNotifications.snapshot();
            device.dbusPath = "preview/power";
            bluetoothNotifications.enqueue(device, true);
        }
        function preview(): void {
            const examples = [
                { name: "Preview · Wireless Controller", kind: "controller", icon: "input-gaming", transport: "Bluetooth" },
                { name: "Preview · Wireless Earbuds", kind: "earbuds", icon: "audio-headphones", transport: "Bluetooth", batteryAvailable: true, battery: 0.75 },
                { name: "Preview · USB Headset", kind: "headphones", icon: "audio-headset", transport: "USB" },
                { name: "Preview · Wireless Controller", kind: "controller", icon: "input-gaming", transport: "Bluetooth", connected: false }
            ];
            for (const device of examples) {
                device.dbusPath = "preview/" + device.name;
                bluetoothNotifications.enqueue(device, device.connected !== false);
            }
        }
    }
    Timer {
        interval: root.bluetoothNoticeMs * 4 + root.entranceMs
        running: root.debugNotifications
        repeat: true
        triggeredOnStart: true
        onTriggered: notchIpc.preview()
    }
    readonly property bool notificationActive: systemOsd.active || bluetoothNotifications.current !== null
    readonly property bool notchVisible: true

    // ---------- Cava Audio Integration ----------
    property int    barCount: 6
    property real   waveformGain: 1.4
    property real   waveformNoiseGate: 0.06
    property var    levels: []

    function waveformLevel(level) {
        if (!Number.isFinite(level)) return 0;
        const gate = Math.max(0, Math.min(0.99, waveformNoiseGate));
        // Gate before applying gain so background noise is not amplified.
        return Math.max(0, Math.min(1, (level / 100 - gate) / (1 - gate) * waveformGain));
    }

    function cavaConfig() {
        return [
            "[general]",
            "bars = " + barCount,
            "framerate = 60",
            "autosens = 1",
            "sensitivity = 50",
            "",
            "[input]",
            "method = pipewire",
            "source = auto",
            "",
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = 100",
            "bar_delimiter = 59",
            "frame_delimiter = 10",
            "channels = mono",
            "mono_option = average",
            "",
            "[smoothing]",
            "monstercat = 0",
            "waves = 1",
            "noise_reduction = 0.77",
            "ignore = " + Math.round(waveformNoiseGate * 100),
        ].join("\n");
    }

    Process {
        id: cava
        running: true
        command: ["sh", "-c",
            'cfg="${XDG_RUNTIME_DIR:-/tmp}/qs-notch-cava.conf"; printf "%s\\n" "$CAVA_CFG" > "$cfg"; exec cava -p "$cfg"']
        environment: ({ CAVA_CFG: root.cavaConfig() })

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue;
                    const level = Number(parts[i]);
                    out.push(root.waveformLevel(level));
                }
                root.levels = out;
            }
        }

        stderr: SplitParser {
            onRead: data => console.log("notch-cava says: " + data)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 127) restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: cava.running = true
    }

    function pickPlayer() {
        const list = Mpris.players.values;
        let fallback = null;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p.playbackState === MprisPlaybackState.Playing) return p;
            if (fallback === null && p.trackTitle !== "") fallback = p;
        }
        return fallback;
    }

    function pickScreen() {
        if (embeddedScreen) return embeddedScreen;
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === screenName) return list[i];
        return list.length > 0 ? list[0] : null;
    }

    function fmt(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(sec / 60), s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ---------- two prominent colours picked from the cover art ----------
    // Lift colours to a readable luminance against the black notch.
    function readableCoverColor(color) {
        function linear(channel) {
            return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
        }
        function luminance(c) {
            return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
        }
        if (luminance(color) >= 0.22) return color;
        // Raise brightness first, preserving hue and saturation for dark artwork.
        const peak = Math.max(color.r, color.g, color.b);
        if (peak > 0) {
            const bright = Qt.rgba(color.r / peak, color.g / peak, color.b / peak, 1);
            if (luminance(bright) >= 0.22) {
                let lowScale = 1, highScale = 1 / peak;
                for (let i = 0; i < 12; i++) {
                    const scale = (lowScale + highScale) / 2;
                    if (luminance(Qt.rgba(color.r * scale, color.g * scale, color.b * scale, 1)) < 0.22)
                        lowScale = scale;
                    else highScale = scale;
                }
                return Qt.rgba(color.r * highScale, color.g * highScale, color.b * highScale, 1);
            }
            color = bright;
        }
        // Deep blues can still be too dim at full brightness; soften them with white.
        let low = 0, high = 1;
        for (let i = 0; i < 12; i++) {
            const mix = (low + high) / 2;
            const lifted = Qt.rgba(color.r + (1 - color.r) * mix,
                                   color.g + (1 - color.g) * mix,
                                   color.b + (1 - color.b) * mix, 1);
            if (luminance(lifted) < 0.22) low = mix;
            else high = mix;
        }
        return Qt.rgba(color.r + (1 - color.r) * high,
                       color.g + (1 - color.g) * high,
                       color.b + (1 - color.b) * high, 1);
    }

    // Sample once per cover; retain dark hues so they can be lightened.
    function paletteFromPixels(d) {
        const bins = {};
        let n = 0;
        for (let i = 0; i + 3 < d.length; i += 4) {
            if (d[i + 3] < 128) continue;                       // see-through pixel
            n++;
            const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255;
            const mx = Math.max(r, g, b), chroma = mx - Math.min(r, g, b);
            // Ignore near-black backgrounds, but keep dark colours and neutral highlights.
            if (mx < 0.015 || (mx < 0.12 && chroma / mx < 0.12)) continue;
            const key = (d[i] >> 4) * 256 + (d[i + 1] >> 4) * 16 + (d[i + 2] >> 4);
            if (!bins[key]) bins[key] = { r: 0, g: 0, b: 0, count: 0 };
            const bin = bins[key];
            bin.r += r; bin.g += g; bin.b += b; bin.count++;
        }
        if (n === 0) return null;
        const samples = Object.values(bins).sort((a, b) => b.count - a.count);
        if (samples.length === 0) return [Qt.rgba(0.92, 0.92, 0.92, 1), Qt.rgba(0.55, 0.55, 0.55, 1)];

        function distance(a, b) {
            return Math.pow(a.r - b.r, 2) + Math.pow(a.g - b.g, 2) + Math.pow(a.b - b.b, 2);
        }
        // Group similar shades and rank their actual coverage, rather than saturation.
        const clusters = [];
        for (const sample of samples) {
            const color = { r: sample.r / sample.count, g: sample.g / sample.count,
                            b: sample.b / sample.count, count: sample.count };
            let nearest = null, nearestDistance = 0.04;
            for (const cluster of clusters) {
                const delta = distance(color, cluster);
                if (delta < nearestDistance) { nearest = cluster; nearestDistance = delta; }
            }
            if (!nearest) { clusters.push(color); continue; }
            const count = nearest.count + color.count;
            nearest.r = (nearest.r * nearest.count + color.r * color.count) / count;
            nearest.g = (nearest.g * nearest.count + color.g * color.count) / count;
            nearest.b = (nearest.b * nearest.count + color.b * color.count) / count;
            nearest.count = count;
        }
        clusters.sort((a, b) => b.count - a.count);
        const main = clusters[0];
        const primary = readableCoverColor(Qt.rgba(main.r, main.g, main.b, 1));
        let secondary = null;
        for (let i = 1; i < clusters.length; i++) {
            if (clusters[i].count < main.count * 0.08) break;
            const c = clusters[i];
            const candidate = readableCoverColor(Qt.rgba(c.r, c.g, c.b, 1));
            if (distance(primary, candidate) > 0.025) { secondary = candidate; break; }
        }
        if (!secondary) {
            secondary = readableCoverColor(primary.r + primary.g + primary.b > 2.2
                ? Qt.darker(primary, 1.4) : Qt.lighter(primary, 1.3));
        }
        return [primary, secondary];
    }

    // the colour actually used by the progress bar and waveform; it fades between songs
    QtObject {
        id: tint
        property bool has: false
        property color picked: "white"
        property color pickedSecondary: "white"
        readonly property color target: (root.tintFromCover && has) ? picked : root.accent
        readonly property color secondaryTarget: (root.tintFromCover && has) ? pickedSecondary : root.accent
        property color value: target
        property color secondaryValue: secondaryTarget
        Behavior on value { ColorAnimation { duration: 450 } }
        Behavior on secondaryValue { ColorAnimation { duration: 450 } }
    }

    readonly property var  player: pickPlayer()
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing

    property bool shown: false
    property bool peek: false
    property bool hovering: false
    property bool hoverLatch: false
    property bool scrubbing: false
    readonly property bool expanded: shown && !notificationActive && !panelOpen && (hoverLatch || scrubbing)
    readonly property bool compact: shown && !notificationActive && !panelOpen && peek && !expanded

    onHoveringChanged: {
        if (hovering) { collapseTimer.stop(); hoverLatch = true; }
        else collapseTimer.restart();
    }
    onScrubbingChanged: {
        if (scrubbing) collapseTimer.stop();
        else if (!hovering) collapseTimer.restart();
    }

    onPlayingChanged: {
        if (playing) { shown = true; lingerTimer.stop(); }
        else if (shown) lingerTimer.restart();
    }

    // Debounce metadata updates so one track switch produces one peek.
    property bool trackWatchingReady: false
    property var lastPeekPlayer: null
    property var lastPeekTrack: null
    function scheduleTrackPeek() {
        if (trackWatchingReady) trackChangeTimer.restart();
    }
    Component.onCompleted: {
        rememberDuration();
        if (playing) shown = true;
        lastPeekPlayer = player;
        lastPeekTrack = player ? player.uniqueId : null;
        trackWatchingReady = true;
    }
    Timer {
        id: trackChangeTimer
        interval: 180
        onTriggered: {
            const p = root.player;
            if (!p || !p.trackTitle) return;
            if (root.lastPeekPlayer === p && root.lastPeekTrack === p.uniqueId) return;
            root.lastPeekPlayer = p;
            root.lastPeekTrack = p.uniqueId;
            root.shown = true;
            root.peek = true;
            peekTimer.restart();
            if (!root.playing) lingerTimer.restart();
        }
    }

    Timer {
        id: collapseTimer
        interval: root.collapseDelayMs
        onTriggered: {
            if (!root.hovering && !root.scrubbing) root.hoverLatch = false;
        }
    }
    Timer {
        id: peekTimer
        interval: Math.max(root.trackPeekMs, compactView.textReadMs)
        onTriggered: root.peek = false
    }
    Timer {
        id: lingerTimer
        interval: root.pausedLingerMs
        onTriggered: { if (root.hoverLatch || root.scrubbing || root.peek) lingerTimer.restart(); else root.shown = false; }
    }

    // Keep the playback clock separate from the pointer's seek preview.
    // Temporary diagnostics: disable after the live seeking issue is resolved.
    property bool debugSeeking: false
    function logSeek(event) {
        if (!debugSeeking) return;
        const p = root.player;
        console.log("notch-seek " + JSON.stringify({
            event: event, player: p ? p.identity : null,
            track: p ? p.uniqueId : null,
            position: p ? p.position : null, livePosition: livePos,
            length: p ? p.length : null, duration: root.mediaDuration,
            positionSupported: p ? p.positionSupported : false,
            lengthSupported: p ? p.lengthSupported : false,
            canSeek: p ? p.canSeek : false, scrubbing: scrubbing
        }));
    }
    Connections {
        target: root.player
        function onTrackTitleChanged() { root.scheduleTrackPeek(); }
        function onLengthChanged() { root.rememberDuration(); }
        function onLengthSupportedChanged() {
            root.rememberDuration();
            root.logSeek("length-support-changed");
        }
        function onPositionSupportedChanged() { root.logSeek("position-support-changed"); }
        function onCanSeekChanged() { root.logSeek("seek-support-changed"); }
    }
    Timer {
        id: seekDiagnosticTimer
        interval: 750
        onTriggered: root.logSeek("after-seek")
    }
    // Firefox can drop mpris:length after seeking, while the track stays the same.
    // Never use its unsupported length fallback (which is actually the position).
    property var durationPlayer: null
    property var durationTrack: null
    property real rememberedDuration: 0
    readonly property real mediaDuration: {
        const p = root.player;
        if (!p) return 0;
        if (p.lengthSupported && Number.isFinite(p.length) && p.length > 0) return p.length;
        return durationPlayer === p && durationTrack === p.uniqueId ? rememberedDuration : 0;
    }
    function rememberDuration() {
        const p = root.player;
        const key = p ? p.uniqueId : null;
        if (durationPlayer !== p || durationTrack !== key) {
            rememberedDuration = 0;
            durationPlayer = p;
            durationTrack = key;
        }
        if (p && p.lengthSupported && Number.isFinite(p.length) && p.length > 0)
            rememberedDuration = p.length;
    }

    property real livePos: 0
    readonly property var trackKey: player ? player.uniqueId : null
    onTrackKeyChanged: { resetProgress(); scheduleTrackPeek(); }
    onPlayerChanged: {
        resetProgress();
        logSeek("player-changed");
        scheduleTrackPeek();
        if (player === null) {
            shown = false;
            peek = false;
            peekTimer.stop();
            lingerTimer.stop();
        }
    }
    onExpandedChanged: { if (expanded) refreshPos(); }

    function resetProgress() {
        rememberDuration();
        scrubbing = false;
        livePos = 0;
        refreshPos();
    }

    function refreshPos() {
        const p = root.player;
        if (!p || !p.positionSupported) { root.livePos = 0; return; }
        p.positionChanged();
        const position = p.position;
        root.livePos = Number.isFinite(position) ? Math.max(0, position) : 0;
    }
    Timer {
        interval: 100
        repeat: true
        running: root.expanded && root.player !== null && !root.scrubbing
        onTriggered: root.refreshPos()
    }

    function seekTo(fraction) {
        const p = root.player;
        root.rememberDuration();
        const duration = root.mediaDuration;
        if (!p || !p.canSeek || duration <= 0 || !Number.isFinite(fraction)) return;
        // Stay just inside the track: a relative seek beyond its end can skip it.
        root.logSeek("before-seek");
        const target = Math.min(Math.max(0, duration - 0.01),
                                Math.max(0, Math.min(1, fraction)) * duration);
        if (p.positionSupported) p.position = target;
        else p.seek(target - p.position);
        root.livePos = target;
        root.logSeek("seek-requested");
        seekDiagnosticTimer.restart();
    }

    // ---------- components ----------
    component CoverArt: Item {
        id: art
        property string source: ""
        property real radius: 12

        Rectangle {
            anchors.fill: parent
            radius: art.radius
            color: "#1a1c2b"
            visible: img.status !== Image.Ready
            Text {
                anchors.centerIn: parent
                text: "♪"
                color: root.accent
                font.pixelSize: parent.height * 0.35
            }
        }
        Image {
            id: img
            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 225
            sourceSize.height: 225
            visible: false
        }
        Rectangle {
            id: mask
            anchors.fill: parent
            radius: art.radius
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: img
            maskEnabled: true
            maskSource: mask
            visible: img.status === Image.Ready
        }
    }

    // Each bar blends both cover colours vertically.
    component WaveBar: Rectangle {
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: tint.value }
            GradientStop { position: 1; color: tint.secondaryValue }
        }
    }

    // Shared small waveform for the collapsed and track-change views.
    component MiniWaveform: Row {
        id: miniWaveform
        property bool active: false
        height: 22
        spacing: 3
        Repeater {
            model: root.barCount
            WaveBar {
                required property int index
                id: barRect
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: currentHeight
                radius: width / 2
                property real currentHeight: 5

                Timer {
                    interval: 16
                    running: miniWaveform.active
                    repeat: true
                    onTriggered: {
                        const rawLevel = root.levels[barRect.index] || 0;
                        const targetVal = root.playing ? 5 + rawLevel * 17 : 5;
                        const lerpFactor = targetVal > barRect.currentHeight ? 0.4 : 0.12;
                        barRect.currentHeight += (targetVal - barRect.currentHeight) * lerpFactor;
                    }
                }
            }
        }
    }

    component GlyphIcon: Canvas {
        id: ic
        property string kind: "play"        // play | pause | next | prev
        property color fg: "white"
        onKindChanged: requestPaint()
        onFgChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = fg;
            ctx.strokeStyle = fg;
            ctx.lineJoin = "round";
            const w = width, h = height;
            const lw = Math.min(w, h) * 0.13;      // stroking the same colour rounds the triangle corners
            const pad = lw / 2;
            ctx.lineWidth = lw;

            function poly(pts) {
                ctx.beginPath();
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
                ctx.closePath();
                ctx.fill();
                ctx.stroke();
            }

            if (kind === "play") {
                poly([[pad + w * 0.06, pad], [w - pad, h / 2], [pad + w * 0.06, h - pad]]);
            } else if (kind === "pause") {
                const bw = w * 0.38;
                ctx.beginPath();
                ctx.roundedRect(w * 0.05, 0, bw, h, bw * 0.3, bw * 0.3);
                ctx.roundedRect(w * 0.57, 0, bw, h, bw * 0.3, bw * 0.3);
                ctx.fill();
            } else if (kind === "next") {          // fast-forward: two right-pointing triangles
                poly([[pad, pad], [w * 0.5, h / 2], [pad, h - pad]]);
                poly([[w * 0.5, pad], [w - pad, h / 2], [w * 0.5, h - pad]]);
            } else {                               // rewind: two left-pointing triangles
                poly([[w * 0.5, pad], [pad, h / 2], [w * 0.5, h - pad]]);
                poly([[w - pad, pad], [w * 0.5, h / 2], [w - pad, h - pad]]);
            }
        }
    }

    component IconButton: Item {
        id: btn
        property string kind: "play"
        property color fg: "white"
        property bool usable: true
        signal activated()

        opacity: usable ? (ma.containsMouse ? 1 : 0.88) : 0.28
        Behavior on opacity { NumberAnimation { duration: 120 } }
        scale: ma.pressed && usable ? 0.86 : (ma.containsMouse && usable ? 1.12 : 1.0)
        Behavior on scale { MotionSpring { responseMs: 200; epsilon: 0.001 } }

        GlyphIcon { anchors.fill: parent; kind: btn.kind; fg: btn.fg }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: btn.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { if (btn.usable) btn.activated(); }
        }
    }

    // ---------- window ----------
    PanelWindow {
        id: win
        screen: root.pickScreen()

        visible: root.embeddedParent === null && !calibrationOverlay.active
        anchors { top: true; left: true; right: true }
        implicitWidth: Math.max(root.expandedWidth, root.compactWidth) + 2 * root.earRadius + 40
        implicitHeight: Math.max(root.expandedHeight + root.safeExpandedOffset,
            root.compactHeight + root.safeCompactOffset) + 30
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {
            readonly property real hoverPadding: root.expanded || root.scrubbing ? 8 : 0
            x: notch.x - hoverPadding
            y: notch.y
            width: root.notchVisible ? notch.width + hoverPadding * 2 : 0
            height: root.notchVisible ? notch.height + hoverPadding : 0
            Region {
                x: detachedStatus.x
                y: detachedStatus.y
                width: root.statusDetachFraction > 0 ? detachedStatus.width : 0
                height: root.statusDetachFraction > 0 ? detachedStatus.height : 0
                radius: root.notchHeight / 2
            }
            Region {
                x: detachedMedia.x; y: detachedMedia.y
                width: detachedMedia.visible ? detachedMedia.width : 0
                height: detachedMedia.visible ? detachedMedia.height : 0
                radius: 17
            }
        }

        Rectangle {
            id: detachedMedia
            parent: root.embeddedParent || win.contentItem
            readonly property real originX: root.cameraLeft - cutout.padding - 29 - (width - 28) / 2
            x: originX + (root.mediaBubbleLeft - width - root.detachedStatusGap - originX) * root.mediaDetachFraction
            readonly property real attachedY: (root.notchHeight - height) / 2 - 2
            y: attachedY + (Math.max(0, (root.notchHeight - height) / 2) - attachedY) * root.mediaDetachFraction
            width: 34; height: 34; radius: 17
            color: "black"
            opacity: root.mediaDetachFraction
            visible: opacity > 0.001
            z: 21
            CoverArt {
                anchors.centerIn: parent
                width: 22; height: 22; radius: 6
                source: root.player ? root.player.trackArtUrl : ""
            }
        }

        Rectangle {
            id: detachedStatus
            parent: root.embeddedParent || win.contentItem
            // A single progress value moves the bubble and its icon together,
            // using the same spring as the notch's width transition.
            readonly property real attachedOffset: 8 - (width - 32) / 2
            x: notch.x + attachedOffset
                + (-root.detachedStatusGap - width - attachedOffset) * root.statusDetachFraction
            readonly property real attachedY: (root.notchHeight - height) / 2 - 2
            y: attachedY + (Math.max(0, (root.notchHeight - height) / 2) - attachedY) * root.statusDetachFraction
            width: 34
            height: width
            radius: height / 2
            color: "black"
            opacity: root.statusDetachFraction
            visible: opacity > 0
            z: 19
        }

        Rectangle {
            visible: root.debugNotch
            z: 999
            x: cutout.valid ? cutout.rect.x : (parent.width - root.notchWidth) / 2
            y: cutout.valid ? cutout.rect.y : 0
            width: cutout.valid ? cutout.rect.width : root.notchWidth
            height: cutout.valid ? cutout.rect.height : root.notchHeight
            color: "#ff0033"
        }

        // Sample a tiny copy of the cover when it loads, without per-frame colour analysis.
        Canvas {
            id: coverProbe
            parent: root.embeddedParent ? notch : win.contentItem
            width: 32
            height: 32
            opacity: 0.01
            z: -1
            renderTarget: Canvas.Image

            property string src: root.player ? root.player.trackArtUrl : ""
            property string previousSrc: ""
            Connections {
                target: root
                function onTintFromCoverChanged() { coverProbe.reload(); }
            }

            function reload() {
                tint.has = false;
                if (previousSrc !== "" && previousSrc !== src) unloadImage(previousSrc);
                previousSrc = src;
                if (src !== "" && root.tintFromCover) {
                    loadImage(src);
                    requestPaint();
                }
            }
            onSrcChanged: reload()
            Component.onCompleted: reload()
            onImageLoaded: requestPaint()

            onPaint: {
                if (!root.tintFromCover || src === "" || !isImageLoaded(src)) return;
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.drawImage(src, 0, 0, width, height);
                const palette = root.paletteFromPixels(ctx.getImageData(0, 0, width, height).data);
                if (palette) {
                    tint.picked = palette[0];
                    tint.pickedSecondary = palette[1];
                    tint.has = true;
                } else {
                    tint.has = false;
                }
            }
        }

        Item {
            id: notch
            parent: root.embeddedParent || win.contentItem
            property real revealProgress: root.notchVisible ? 1 : 0
            Behavior on revealProgress {
                MotionSpring { responseMs: root.entranceMs; smooth: true; epsilon: 0.001 }
            }
            // Output-local positioning preserves fractional calibration coordinates;
            // the Qt backing surface can have a slightly different rounded width.
            x: root.cameraRight + rightExtent - width
            // Animate the right edge independently so asymmetric wings keep their placement.
            property real rightExtent: (root.statusOnly ? 0 : systemOsd.active ? root.osdRightWidth
                : root.chargingNotice ? root.chargingRightWidth
                : root.notificationActive ? root.notificationRightExtent
                : root.expanded ? (root.expandedWidth - root.notchWidth) / 2
                : root.compact ? (root.compactWidth - root.notchWidth) / 2
                : root.shown ? root.wingWidth + root.safeMediaRightExtra : 0)
            Behavior on rightExtent {
                MotionSpring { responseMs: root.animMs }
            }
            y: 0
            opacity: root.notchVisible ? 1 : 0

            width: root.attachedStatusWidth + (root.statusOnly ? root.notchWidth : systemOsd.active ? root.notchWidth + root.osdLeftWidth + root.osdRightWidth
                 : root.chargingNotice ? root.notchWidth + root.chargingLeftWidth + root.chargingRightWidth
                 : root.notificationActive ? root.notchWidth + root.notificationWingWidth
                       - root.notificationLeftInset + root.safeNoticeLeftExtra + root.notificationRightExtent
                 : root.expanded ? root.expandedWidth
                 : root.compact ? root.compactWidth
                 : (root.notchVisible ? root.notchWidth + 2 * root.wingWidth - root.collapsedLeftInset
                     + root.safeMediaLeftExtra + root.safeMediaRightExtra : root.notchWidth))
            // Safety padding excludes foreground content; it never adds to
            // the resting black body's calibrated height, even with a battery.
            property real motionHeight: root.expanded ? root.expandedHeight + root.safeExpandedOffset
                : root.compact ? root.compactHeight + root.safeCompactOffset
                : root.notchHeight
            height: Math.max(root.notchHeight, motionHeight)
            Behavior on motionHeight { MotionSpring { responseMs: root.animMs; smooth: true } }

            // Use a subtler screen join while collapsed.
            property real ear: root.expanded ? root.earRadius : root.compact ? 8 : root.screenJoinRadius
            Behavior on ear { MotionSpring { responseMs: root.animMs; smooth: true } }

            Behavior on width {
                MotionSpring { responseMs: root.animMs }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.notchVisible ? 180 : 140
                    easing.type: Easing.OutCubic
                }
            }

            // Observe the whole media subtree, including its interactive
            // children. A sibling hover surface loses hover to seek/buttons.
            HoverHandler {
                id: mediaHover
                enabled: root.shown && !root.notificationActive && !root.controlCenterOpen
                blocking: false
                margin: root.hoverLatch || root.scrubbing ? 8 : 0
                onHoveredChanged: root.hovering = hovered
            }
            Indicator.ConnectionIndicator {
                id: statusIndicator
                visible: !root.panelOpen
                parent: root.embeddedParent || win.contentItem
                x: detachedStatus.x + (detachedStatus.width - width) / 2
                y: detachedStatus.y + (detachedStatus.height - height) / 2
                width: 32 - 6 * root.statusDetachFraction
                height: width
                z: 20
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.activeControlCenter) root.activeControlCenter.toggle(); }
                }
            }

            Rectangle {
                id: body
                property real r: root.expanded ? root.expandedRadius : root.compact ? 24 : root.collapsedRadius
                Behavior on r { MotionSpring { responseMs: root.animMs; smooth: true } }
                y: -r
                width: parent.width
                height: parent.height + r
                radius: r
                color: "black"
            }

            // left ear: a black corner piece with a quarter circle cut out, so the sides of the
            // notch flare outward into the top edge of the screen
            Canvas {
                visible: notch.ear > 0.5
                width: notch.ear + 1
                height: notch.ear
                x: -notch.ear
                y: 0
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const e = width - 1;
                    ctx.fillStyle = "black";
                    ctx.beginPath();
                    ctx.moveTo(e + 1, 0);
                    ctx.lineTo(e + 1, e);
                    ctx.lineTo(e, e);
                    ctx.arc(0, e, e, 0, -Math.PI / 2, true);
                    ctx.closePath();
                    ctx.fill();
                }
            }
            // right ear: the mirror image
            Canvas {
                visible: notch.ear > 0.5
                width: notch.ear + 1
                height: notch.ear
                x: notch.width - 1
                y: 0
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const e = width - 1;
                    ctx.fillStyle = "black";
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(0, e);
                    ctx.lineTo(1, e);
                    ctx.arc(1 + e, e, e, Math.PI, 1.5 * Math.PI, false);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            // Hard exclusion also protects transitional frames as the widget moves/resizes.
            Canvas {
                id: cutoutMask
                width: notch.width; height: notch.height
                property real holeX: cutout.valid ? cutout.rect.x - notch.x - cutout.padding : 0
                property real holeY: cutout.valid ? cutout.rect.y - notch.y - cutout.padding : 0
                property real holeWidth: cutout.valid ? cutout.rect.width + cutout.padding * 2 : 0
                property real holeHeight: cutout.valid ? cutout.rect.height + cutout.padding * 2 : 0
                onHoleXChanged: requestPaint()
                onHoleYChanged: requestPaint()
                onHoleWidthChanged: requestPaint()
                onHoleHeightChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "white";
                    ctx.fillRect(0, 0, width, height);
                    ctx.clearRect(Math.floor(holeX), Math.floor(holeY),
                        Math.ceil(holeX + holeWidth) - Math.floor(holeX),
                        Math.ceil(holeY + holeHeight) - Math.floor(holeY));
                }
            }
            ShaderEffectSource {
                id: cutoutTexture
                sourceItem: cutoutMask
                hideSource: true
                visible: false
                live: true
            }

            // Only foreground content is masked; the black background may span the cutout.
            Item {
                id: safeContent
                anchors.fill: parent
                clip: true
                visible: cutout.saved === null || cutout.valid
                layer.enabled: cutout.valid
                layer.effect: MultiEffect { maskEnabled: true; maskSource: cutoutTexture }

                // ===== collapsed view =====
                MotionContent {
                    id: collapsedView
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: parent.width
                    height: root.notchHeight
                    active: !root.expanded && !root.compact && !root.notificationActive && !root.panelOpen

                    CoverArt {
                        id: collapsedArt
                        x: cutout.valid ? cutout.rect.x - notch.x - collapsedView.x - cutout.padding - width - 1
                                - (1 - notch.revealProgress) * 8
                            : (parent.width - width) / 2 * (1 - notch.revealProgress) + 6 * notch.revealProgress
                        y: cutout.valid ? (root.notchHeight - height) / 2 - 1.8 : 2
                        height: 28
                        width: 28
                        radius: 8
                        source: root.player ? root.player.trackArtUrl : ""
                        opacity: root.shown && !root.notificationActive ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }

                    MiniWaveform {
                        id: collapsedWaveform
                        x: cutout.valid ? cutout.rect.x + cutout.rect.width - notch.x - collapsedView.x + cutout.padding
                                + (1 - notch.revealProgress) * 8
                            : (parent.width - width) / 2 * (1 - notch.revealProgress)
                                + (parent.width - width - 14) * notch.revealProgress
                        anchors.verticalCenter: parent.verticalCenter
                        active: collapsedView.visible && root.shown
                        opacity: root.shown ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                }

                // A device symbol briefly replaces the cover in the left wing.
                MotionContent {
                    id: notificationView
                    anchors.left: parent.left
                    width: parent.width
                    height: root.notchHeight
                    active: root.notificationActive && !root.chargingNotice && !systemOsd.active
                    enabled: false
                    // Retain the last symbol while this view fades away.
                    property var notice: null
                    Connections {
                        target: bluetoothNotifications
                        function onCurrentChanged() {
                            const next = bluetoothNotifications.current;
                            if (next === null || next.kind === "charging") return;
                            const swapped = notificationView.notice !== null
                                && (notificationView.notice.key !== next.key || notificationView.notice.kind !== next.kind);
                            notificationView.notice = next;
                            if (swapped) noticeReveal.restart();
                        }
                    }
                    NumberAnimation {
                        id: noticeReveal
                        target: deviceSymbol
                        property: "opacity"
                        from: 0; to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                    DeviceSymbol {
                        id: deviceSymbol
                        x: cutout.valid ? cutout.rect.x - notch.x - cutout.padding - width - 4 : 8
                        y: cutout.valid ? (root.notchHeight - height) / 2 : 3
                        width: 28
                        height: 28
                        kind: notificationView.notice ? notificationView.notice.kind : "bluetooth"
                        fallbackIcon: notificationView.notice ? notificationView.notice.icon : "bluetooth"
                    }
                    // Only real, reported battery levels reserve a trailing wing.
                    Item {
                        id: deviceBattery
                        x: (cutout.valid ? root.cameraRight + cutout.padding
                            : ((root.embeddedParent ? root.embeddedParent.width : win.width) + root.notchWidth) / 2)
                            - notch.x + 4
                        y: (root.notchHeight - height) / 2
                        width: 28
                        height: 28
                        visible: root.notificationActive && root.notificationHasBattery
                        readonly property real level: root.notificationHasBattery ? root.notificationBattery : 0
                        readonly property color ringColor: level <= 0.2 ? "#ff654f" : "#30df74"
                        Canvas {
                            id: batteryCanvas
                            anchors.fill: parent
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.lineWidth = 2.5;
                                ctx.strokeStyle = Qt.rgba(deviceBattery.ringColor.r, deviceBattery.ringColor.g,
                                    deviceBattery.ringColor.b, 0.25);
                                ctx.beginPath();
                                ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2);
                                ctx.stroke();
                                if (deviceBattery.level > 0) {
                                    ctx.strokeStyle = deviceBattery.ringColor;
                                    ctx.lineCap = "round";
                                    ctx.beginPath();
                                    ctx.arc(width / 2, height / 2, width / 2 - 2,
                                        -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * deviceBattery.level);
                                    ctx.stroke();
                                }
                            }
                            Connections {
                                target: deviceBattery
                                function onLevelChanged() { batteryCanvas.requestPaint(); }
                                function onRingColorChanged() { batteryCanvas.requestPaint(); }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(deviceBattery.level * 100)
                            color: deviceBattery.ringColor
                            font.family: root.fontFamily
                            font.pixelSize: deviceBattery.level === 1 ? 9 : 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                MotionContent {
                    anchors.fill: parent
                    active: systemOsd.active
                    enabled: false
                    SfSymbol {
                        width: 24; height: 24
                        x: root.cameraLeft - cutout.padding - notch.x - width - 8
                        y: (root.notchHeight - height) / 2 - 2
                        symbolName: systemOsd.symbolName
                        fallbackIcon: systemOsd.kind === "brightness" ? "display-brightness" : "audio-volume-high"
                    }
                    Rectangle {
                        id: osdGauge
                        x: root.cameraRight + cutout.padding - notch.x + 8
                        y: (root.notchHeight - height) / 2
                        width: 55; height: 6; radius: 3
                        color: "#44444a"
                        clip: true
                        Rectangle {
                            width: parent.width * (systemOsd.muted ? 0 : systemOsd.level)
                            height: parent.height; radius: 3
                            color: "white"
                            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text {
                        x: osdGauge.x + osdGauge.width + 8
                        y: (root.notchHeight - height) / 2
                        text: systemOsd.label
                        color: "white"
                        font: osdLabelMetrics.font
                    }
                }

                // Charging uses both side wings; the calibrated camera remains empty.
                MotionContent {
                    id: chargingView
                    anchors.fill: parent
                    active: root.chargingNotice
                    enabled: false
                    Text {
                        id: chargingLabel
                        x: (cutout.valid ? root.cameraLeft - cutout.padding : root.cameraLeft)
                            - notch.x - width
                        y: (root.notchHeight - height) / 2
                        text: root.powerNoticeLabel
                        color: "white"
                        font: chargingLabelMetrics.font
                    }
                    Row {
                        id: chargingStatus
                        x: root.cameraRight + cutout.padding - notch.x
                        y: (root.notchHeight - height) / 2
                        height: 24
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.chargingPercentage
                            visible: root.notificationHasBattery
                            color: root.powerNoticeColor
                            font: chargingPercentMetrics.font
                        }
                        SfSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 22
                            symbolName: "battery.rtl.fill"
                            mirror: true
                            symbolColor: root.powerNoticeColor
                        }
                    }
                }

                // Compact track-change peek sits below the physical camera notch.
                MotionContent {
                    id: compactView
                    entranceOffset: 5
                    y: root.safeCompactOffset
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.attachedStatusWidth / 2
                    width: root.compactWidth
                    height: root.compactHeight
                    active: root.compact

                    // Leave time to read both ends of any overflowing metadata.
                    readonly property real textReadMs: Math.max(
                        compactTitle.overflow > 0 ? compactTitle.scrollDuration + 2 * compactTitle.readPauseMs : 0,
                        compactArtist.overflow > 0 ? compactArtist.scrollDuration + 2 * compactArtist.readPauseMs : 0)

                    CoverArt {
                        id: compactArt
                        x: root.compactPadding
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.compactPadding
                        width: 40
                        height: 40
                        radius: 11
                        source: root.player ? root.player.trackArtUrl : ""
                    }
                    RibbonText {
                        id: compactTitle
                        x: compactArt.x + compactArt.width + root.compactPadding
                        y: compactArt.y + (compactArt.height - height
                            - (compactArtist.visible ? compactArtist.height + 3 : 0)) / 2
                        width: Math.max(0, compactWaveform.x - x - root.compactPadding)
                        text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                        fontFamily: root.fontFamily
                        pixelSize: 14
                        active: root.compact
                        resetKey: root.trackKey
                    }
                    RibbonText {
                        id: compactArtist
                        x: compactTitle.x
                        y: compactTitle.y + compactTitle.height + 3
                        width: compactTitle.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                        visible: text.length > 0
                        fontFamily: root.fontFamily
                        pixelSize: 11.5
                        weight: Font.Normal
                        textColor: root.dim
                        pixelsPerSecond: 24
                        active: root.compact
                        resetKey: root.trackKey
                    }
                    MiniWaveform {
                        id: compactWaveform
                        anchors.right: parent.right
                        anchors.rightMargin: root.compactPadding
                        y: compactArt.y + compactArt.height / 2 - height / 2
                        active: compactView.visible
                    }
                }

                // ===== expanded view =====
                // Scaled artwork and glyphs share rows with consistent logical insets.
                MotionContent {
                    id: expandedView
                    entranceOffset: 6
                    property real k: root.uiScale
                    readonly property real layoutInset: root.compactPadding
                    readonly property real progressInset: layoutInset + 14
                    readonly property real metadataHeight: trackTitle.height
                        + (trackArtist.visible ? trackArtist.height + 4 : 0)
                    readonly property real controlsCenterY: height - layoutInset - 23 * k - 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.attachedStatusWidth / 2
                    y: root.safeExpandedOffset
                    width: root.expandedWidth
                    height: root.expandedHeight
                    active: root.expanded

                    // cover art
                    CoverArt {
                        id: bigArt
                        x: expandedView.layoutInset
                        y: 37 * expandedView.k
                        width: 112 * expandedView.k
                        height: 112 * expandedView.k
                        radius: 22 * expandedView.k
                        source: root.player ? root.player.trackArtUrl : ""
                    }

                    // Two metadata lines beside the cover, with space for the waveform.
                    RibbonText {
                        id: trackTitle
                        x: bigArt.x + bigArt.width + expandedView.layoutInset
                        y: bigArt.y + (bigArt.height - expandedView.metadataHeight) / 2
                        width: Math.max(0, expandedWaveform.x - x - expandedView.layoutInset)
                        text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                        fontFamily: root.fontFamily
                        pixelSize: 26 * expandedView.k
                        active: root.expanded
                        resetKey: root.trackKey
                    }
                    RibbonText {
                        id: trackArtist
                        x: trackTitle.x
                        y: trackTitle.y + trackTitle.height + 4
                        width: trackTitle.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || "") : ""
                        visible: text.length > 0
                        textColor: root.dim
                        fontFamily: root.fontFamily
                        pixelSize: 22 * expandedView.k
                        weight: Font.Normal
                        pixelsPerSecond: 24
                        active: root.expanded
                        resetKey: root.trackKey
                    }

                    // Activity indicator aligned with the metadata row.
                    Row {
                        id: expandedWaveform
                        readonly property real barScale: expandedView.k * 1.4
                        x: expandedView.width - expandedView.layoutInset - width
                        y: bigArt.y + (bigArt.height - height) / 2
                        height: 26 * barScale
                        spacing: 4 * barScale
                        Repeater {
                            model: root.barCount

                            WaveBar {
                                required property int index
                                id: barRect
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4 * expandedWaveform.barScale
                                radius: width / 2

                                property real currentHeight: 6 * expandedWaveform.barScale

                                Timer {
                                    interval: 16
                                    running: expandedView.visible
                                    repeat: true
                                    onTriggered: {
                                        var rawLevel = root.levels[index] || 0.0;
                                        var targetVal = root.playing ? (6 * expandedWaveform.barScale + rawLevel * 14 * expandedWaveform.barScale) : 6 * expandedWaveform.barScale;
                                        var lerpFactor = targetVal > barRect.currentHeight ? 0.4 : 0.12;
                                        barRect.currentHeight += (targetVal - barRect.currentHeight) * lerpFactor;
                                    }
                                }

                                height: currentHeight
                            }
                        }
                    }

                    // elapsed time, progress bar, time remaining
                    Item {
                        id: progress
                        x: elapsedTime.x + elapsedTime.width + 16 * expandedView.k
                        y: bigArt.y + bigArt.height + expandedView.layoutInset
                        width: Math.max(0, remainingTime.x - 16 * expandedView.k - x)
                        height: 24 * expandedView.k

                        // Read the player once in each binding: derived capability flags can
                        // briefly outlive their player during MPRIS service replacement.
                        readonly property real duration: root.mediaDuration
                        readonly property bool known: duration > 0
                        readonly property bool seekable: {
                            const p = root.player;
                            return p !== null && p.canSeek && duration > 0;
                        }
                        property real previewRatio: 0
                        readonly property real displayedPosition: root.scrubbing
                                                                 ? previewRatio * duration : root.livePos
                        readonly property real ratio: root.scrubbing ? previewRatio
                            : (duration > 0 ? Math.min(1, Math.max(0, root.livePos / duration)) : 0)

                        function preview(x) {
                            previewRatio = Math.max(0, Math.min(1, x / width));
                        }
                        onSeekableChanged: { if (!seekable) root.scrubbing = false; }

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: (root.scrubbing || seekArea.containsMouse ? 12 : 8) * expandedView.k
                            radius: height / 2
                            color: "#303036"
                            Behavior on height { NumberAnimation { duration: 120 } }
                            Rectangle {
                                // Keep a full round cap at the start of a track.
                                width: Math.min(parent.width, Math.max(parent.height, parent.width * progress.ratio))
                                height: parent.height
                                radius: height / 2
                                visible: progress.ratio > 0
                                color: tint.value
                            }
                        }
                        Rectangle {
                            width: 18 * expandedView.k
                            height: width
                            radius: width / 2
                            x: Math.max(0, Math.min(progress.width - width, progress.width * progress.ratio - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            color: "white"
                            opacity: progress.seekable && (root.scrubbing || seekArea.containsMouse) ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            anchors.topMargin: -6
                            anchors.bottomMargin: -6
                            hoverEnabled: true
                            enabled: progress.seekable
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onPressed: mouse => {
                                progress.preview(mouse.x);
                                root.scrubbing = true;
                                root.logSeek("drag-start");
                            }
                            onPositionChanged: mouse => {
                                if (pressed && root.scrubbing) progress.preview(mouse.x);
                            }
                            onReleased: mouse => {
                                if (!root.scrubbing) return;
                                progress.preview(mouse.x);
                                root.seekTo(progress.previewRatio);
                                root.scrubbing = false;
                            }
                            onCanceled: {
                                root.logSeek("drag-canceled");
                                root.scrubbing = false;
                            }
                        }
                    }
                    Text {
                        id: elapsedTime
                        x: expandedView.progressInset
                        anchors.verticalCenter: progress.verticalCenter
                        height: 32 * expandedView.k
                        verticalAlignment: Text.AlignVCenter
                        text: root.player ? root.fmt(progress.displayedPosition) : ""
                        visible: progress.known
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 22 * expandedView.k
                    }
                    Text {
                        id: remainingTime
                        x: expandedView.width - expandedView.progressInset - width
                        anchors.verticalCenter: progress.verticalCenter
                        height: elapsedTime.height
                        verticalAlignment: Text.AlignVCenter
                        text: root.player ? "-" + root.fmt(Math.max(0, progress.duration - progress.displayedPosition)) : ""
                        visible: progress.known
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: elapsedTime.font.pixelSize
                    }

                    // rewind  /  play-pause  /  fast-forward, centred on the panel
                    IconButton {
                        id: previousButton
                        width: 51 * expandedView.k
                        height: 30 * expandedView.k
                        x: expandedView.width / 2 - 142 * expandedView.k - width / 2
                        y: expandedView.controlsCenterY - height / 2
                        kind: "prev"
                        usable: root.player !== null && root.player.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    IconButton {
                        id: playPauseButton
                        width: 38 * expandedView.k
                        height: 46 * expandedView.k
                        x: expandedView.width / 2 - width / 2
                        y: expandedView.controlsCenterY - height / 2
                        kind: root.playing ? "pause" : "play"
                        usable: root.player !== null && root.player.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    IconButton {
                        id: nextButton
                        width: 51 * expandedView.k
                        height: 30 * expandedView.k
                        x: expandedView.width / 2 + 142 * expandedView.k - width / 2
                        y: expandedView.controlsCenterY - height / 2
                        kind: "next"
                        usable: root.player !== null && root.player.canGoNext
                        onActivated: root.player.next()
                    }
                }
            }
        }
    }
}
