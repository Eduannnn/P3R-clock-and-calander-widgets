// Dynamic-Island style media widget that lives in the MacBook notch.
// Run with:  quickshell -p island.qml

import QtQuick
import "."
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io

ShellRoot {
    id: root

    // ---------- notch calibration ----------
    property real notchWidth: 280
    property real notchHeight: 38
    property bool debugNotch: false
    property string screenName: "eDP-1"

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
    property real   earRadius: 16  // the concave corners where the island meets the top of the screen
    property color  accent: "#49fffe"        // Persona cyan accent (used when the cover has no usable colour)
    property bool   tintFromCover: true      // progress bar + waveform take the cover art's main colour
    property color  dim: "#9aa0b4"           // Secondary text
    property string fontFamily: "sans-serif"
    property int    animMs: 280              // Snappy, fast open/close speed
    property int    entranceMs: 420          // gentler reveal when media first starts
    property int    pausedLingerMs: 12000
    property int    trackPeekMs: 3500
    property int    collapseDelayMs: 350

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
    // Lift colours to a readable luminance against the black island.
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
    property bool opening: false
    onShownChanged: {
        opening = shown;
        if (shown) entranceTimer.restart();
        else entranceTimer.stop();
    }
    Timer {
        id: entranceTimer
        interval: root.entranceMs
        onTriggered: root.opening = false
    }
    property bool peek: false
    property bool hovering: false
    property bool hoverLatch: false
    property bool scrubbing: false
    readonly property bool expanded: shown && (hoverLatch || scrubbing)
    readonly property bool compact: shown && peek && !expanded

    onHoveringChanged: {
        if (hovering) { collapseTimer.stop(); hoverLatch = true; }
        else collapseTimer.restart();
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

    Timer { id: collapseTimer; interval: root.collapseDelayMs; onTriggered: root.hoverLatch = false }
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
        console.log("island-seek " + JSON.stringify({
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
        Behavior on scale { NumberAnimation { duration: 90 } }

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

        anchors { top: true }
        implicitWidth: Math.max(root.expandedWidth, root.compactWidth) + 2 * root.earRadius + 40
        implicitHeight: Math.max(root.expandedHeight, root.compactHeight) + 30
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {
            x: island.x
            y: island.y
            width: root.shown ? island.width : 0
            height: root.shown ? island.height : 0
        }

        Rectangle {
            visible: root.debugNotch
            z: 999
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: root.notchWidth
            height: root.notchHeight
            color: "#ff0033"
        }

        // Sample a tiny copy of the cover when it loads, without per-frame colour analysis.
        Canvas {
            id: coverProbe
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
            id: island
            readonly property bool enteringCollapsed: root.opening && !root.expanded && !root.compact
            property real revealProgress: root.shown ? 1 : 0
            Behavior on revealProgress {
                NumberAnimation { duration: root.entranceMs; easing.type: Easing.InOutCubic }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: leftInset / 2
            property real leftInset: root.shown && !root.expanded && !root.compact
                ? root.collapsedLeftInset : 0
            Behavior on leftInset {
                NumberAnimation {
                    duration: island.enteringCollapsed ? root.entranceMs : root.animMs
                    easing.type: island.enteringCollapsed ? Easing.InOutCubic : Easing.OutCubic
                }
            }
            y: 0
            opacity: root.shown ? 1 : 0

            width: root.expanded ? root.expandedWidth
                 : root.compact ? root.compactWidth
                 : (root.shown ? root.notchWidth + 2 * root.wingWidth - root.collapsedLeftInset : root.notchWidth)
            height: root.expanded ? root.expandedHeight : root.compact ? root.compactHeight : root.notchHeight

            // Use a subtler screen join while collapsed.
            property real ear: root.expanded ? root.earRadius : root.compact ? 8 : 6
            Behavior on ear { NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }

            Behavior on width {
                NumberAnimation {
                    duration: island.enteringCollapsed ? root.entranceMs : root.animMs
                    easing.type: island.enteringCollapsed ? Easing.InOutCubic : Easing.OutCubic
                }
            }
            Behavior on height { NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.shown ? root.entranceMs : 200
                    easing.type: Easing.InOutCubic
                }
            }

            HoverHandler {
                onHoveredChanged: root.hovering = hovered
            }

            Rectangle {
                id: body
                property real r: root.expanded ? root.expandedRadius : root.compact ? 24 : root.collapsedRadius
                Behavior on r { NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic } }
                y: -r
                width: parent.width
                height: parent.height + r
                radius: r
                color: "black"
            }

            // left ear: a black corner piece with a quarter circle cut out, so the sides of the
            // island flare outward into the top edge of the screen
            Canvas {
                visible: island.ear > 0.5
                width: island.ear + 1
                height: island.ear
                x: -island.ear
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
                visible: island.ear > 0.5
                width: island.ear + 1
                height: island.ear
                x: island.width - 1
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

            // everything inside the island is clipped to it while it grows and shrinks
            Item {
                anchors.fill: parent
                clip: true

                // ===== collapsed view =====
                Item {
                    id: collapsedView
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: root.notchWidth + 2 * root.wingWidth - root.collapsedLeftInset
                    height: root.notchHeight
                    opacity: root.expanded || root.compact ? 0 : 1
                    visible: opacity > 0.01
                    enabled: !root.expanded && !root.compact
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    CoverArt {
                        x: (parent.width - width) / 2 * (1 - island.revealProgress)
                            + 8 * island.revealProgress
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        height: 28
                        width: 28
                        radius: 8
                        source: root.player ? root.player.trackArtUrl : ""
                    }

                    MiniWaveform {
                        x: (parent.width - width) / 2 * (1 - island.revealProgress)
                            + (parent.width - width - 14) * island.revealProgress
                        anchors.verticalCenter: parent.verticalCenter
                        active: collapsedView.visible
                    }
                }

                // Compact track-change peek sits below the physical camera notch.
                Item {
                    id: compactView
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.compactWidth
                    height: root.compactHeight
                    opacity: root.compact ? 1 : 0
                    visible: opacity > 0.01
                    enabled: root.compact
                    Behavior on opacity { NumberAnimation { duration: 160 } }

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
                        y: compactArt.y + 2
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
                        y: compactArt.y + 23
                        width: compactTitle.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || root.player.identity) : ""
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
                // Coordinates share a reference size of 688 x 334 and scale together.
                Item {
                    id: expandedView
                    property real k: root.uiScale
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: root.expandedWidth
                    height: root.expandedHeight
                    opacity: root.expanded ? 1 : 0
                    visible: opacity > 0.01
                    enabled: root.expanded
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // cover art
                    CoverArt {
                        id: bigArt
                        x: 37 * expandedView.k
                        y: 37 * expandedView.k
                        width: 112 * expandedView.k
                        height: 112 * expandedView.k
                        radius: 22 * expandedView.k
                        source: root.player ? root.player.trackArtUrl : ""
                    }

                    // Two metadata lines beside the cover, with space for the waveform.
                    RibbonText {
                        id: trackTitle
                        x: 181 * expandedView.k
                        y: 61 * expandedView.k
                        width: expandedWaveform.x - x - 24 * expandedView.k
                        text: root.player ? (root.player.trackTitle || root.player.identity) : ""
                        fontFamily: root.fontFamily
                        pixelSize: 26 * expandedView.k
                        active: root.expanded
                        resetKey: root.trackKey
                    }
                    RibbonText {
                        id: trackArtist
                        x: 181 * expandedView.k
                        y: 94 * expandedView.k
                        width: trackTitle.width
                        text: root.player ? (root.player.trackArtist || root.player.trackAlbum || root.player.identity) : ""
                        textColor: root.dim
                        fontFamily: root.fontFamily
                        pixelSize: 26 * expandedView.k
                        weight: Font.Normal
                        pixelsPerSecond: 24
                        active: root.expanded
                        resetKey: root.trackKey
                    }

                    // Small activity indicator aligned with the metadata row.
                    Row {
                        id: expandedWaveform
                        x: 637 * expandedView.k - width
                        y: 85 * expandedView.k - height / 2
                        height: 26 * expandedView.k
                        spacing: 4 * expandedView.k
                        Repeater {
                            model: root.barCount

                            WaveBar {
                                required property int index
                                id: barRect
                                anchors.verticalCenter: parent.verticalCenter
                                width: 4 * expandedView.k
                                radius: width / 2

                                property real currentHeight: 6 * expandedView.k

                                Timer {
                                    interval: 16
                                    running: expandedView.visible
                                    repeat: true
                                    onTriggered: {
                                        var rawLevel = root.levels[index] || 0.0;
                                        var targetVal = root.playing ? (6 * expandedView.k + rawLevel * 14 * expandedView.k) : 6 * expandedView.k;
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
                        y: 180 * expandedView.k
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
                        x: bigArt.x
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
                        x: expandedView.width - bigArt.x - width
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
                        width: 51 * expandedView.k
                        height: 30 * expandedView.k
                        x: 202 * expandedView.k - width / 2
                        y: 263 * expandedView.k - height / 2
                        kind: "prev"
                        usable: root.player !== null && root.player.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    IconButton {
                        width: 38 * expandedView.k
                        height: 46 * expandedView.k
                        x: 344 * expandedView.k - width / 2
                        y: 263 * expandedView.k - height / 2
                        kind: root.playing ? "pause" : "play"
                        usable: root.player !== null && root.player.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    IconButton {
                        width: 51 * expandedView.k
                        height: 30 * expandedView.k
                        x: 486 * expandedView.k - width / 2
                        y: 263 * expandedView.k - height / 2
                        kind: "next"
                        usable: root.player !== null && root.player.canGoNext
                        onActivated: root.player.next()
                    }
                }
            }
        }
    }
}
