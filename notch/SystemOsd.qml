import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../common/AudioLevel.js" as AudioLevel

QtObject {
    id: osd
    // Plasma already provides its own OSD. Enable this automatically in Hyprland.
    property bool enabled: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    property int displayMs: 1500
    property int brightnessPollMs: 33
    property bool active: false
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property bool armed: false
    property real previousVolume: NaN
    property bool previousMuted: false
    property real previousBrightness: NaN
    property string backlightPath: ""
    property real maximumBrightness: 0
    readonly property var sink: enabled ? Pipewire.defaultAudioSink : null
    readonly property string label: kind === "volume" && muted ? "Muted"
        : (kind === "volume" ? AudioLevel.percentage(level) : Math.round(level * 100)) + "%"
    readonly property string symbolName: kind === "brightness" ? "sun.max.fill"
        : muted || level === 0 ? "speaker.slash.fill"
        : level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"

    function show(nextKind, nextLevel, nextMuted) {
        if (!enabled || !Number.isFinite(nextLevel) || (nextKind !== "volume" && nextKind !== "brightness")) return;
        kind = nextKind;
        level = Math.max(0, Math.min(1, nextLevel));
        muted = nextKind === "volume" && nextMuted;
        active = true;
        dismiss.restart();
    }
    function observeVolume() {
        if (!sink || !sink.audio || !Number.isFinite(sink.audio.volume)) return;
        const value = sink.audio.volume;
        const isMuted = sink.audio.muted;
        if (armed && Number.isFinite(previousVolume)
            && (Math.abs(value - previousVolume) > 0.0001 || isMuted !== previousMuted)) show("volume", value, isMuted);
        previousVolume = value;
        previousMuted = isMuted;
    }
    function observeBrightness(value) {
        if (!Number.isFinite(value) || maximumBrightness <= 0) return;
        const fraction = value / maximumBrightness;
        if (armed && Number.isFinite(previousBrightness) && Math.abs(fraction - previousBrightness) > 0.0001)
            show("brightness", fraction, false);
        previousBrightness = fraction;
    }
    onSinkChanged: { previousVolume = NaN; observeVolume(); }
    onEnabledChanged: { if (!enabled) { active = false; armed = false; } }
    property PwObjectTracker audioTracker: PwObjectTracker { objects: osd.sink ? [osd.sink] : [] }
    property Connections audioChanges: Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumesChanged() { osd.observeVolume(); }
        function onMutedChanged() { osd.observeVolume(); }
    }
    property Timer startup: Timer {
        interval: 1000; running: osd.enabled
        onTriggered: { osd.observeVolume(); osd.armed = true; }
    }
    property Timer dismiss: Timer { interval: osd.displayMs; onTriggered: osd.active = false }

    // Discover once, then read sysfs directly. No subprocess runs on each poll.
    property Process discoverBacklight: Process {
        running: osd.enabled
        command: ["sh", "-c", 'for device in /sys/class/backlight/*; do if [ -r "$device/brightness" ]; then printf "%s" "$device"; break; fi; done']
        stdout: StdioCollector { onStreamFinished: osd.backlightPath = text.trim() }
    }
    property FileView backlightMaximum: FileView {
        path: osd.backlightPath ? osd.backlightPath + "/max_brightness" : ""
        printErrors: false
        onLoaded: { osd.maximumBrightness = Number(text().trim()); osd.backlightValue.reload(); }
    }
    property FileView backlightValue: FileView {
        path: osd.backlightPath ? osd.backlightPath + "/brightness" : ""
        printErrors: false
        onLoaded: osd.observeBrightness(Number(text().trim()))
    }
    property Timer brightnessPoll: Timer {
        // Sysfs has no reliable change signal; sample quickly enough for the
        // shared gauge animation to follow key repeats and slider movement.
        interval: osd.brightnessPollMs
        running: osd.enabled && osd.backlightPath !== ""
        repeat: true
        onTriggered: osd.backlightValue.reload()
    }
}
