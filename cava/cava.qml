// Full-width audio visualiser along the bottom edge of the screen, driven by cava.
// Run with:  quickshell -p cava.qml
//
// Needs `cava` installed and on your PATH (NixOS: add pkgs.cava to your packages).
// Quickshell has no audio-spectrum support of its own, so this launches cava in "raw" mode,
// reads the bar heights it prints, and draws them as plain rectangles (cheap for the GPU).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ---------- tweakable stuff ----------
    property int    bars: 60                  // number of bars across the screen (fewer = thicker bars)
                                              // use an EVEN number: cava works in left/right pairs, and an
                                              // odd number (like 65) breaks it. Odd values are bumped up by 1.
    readonly property int barCount: bars + (bars % 2)

    // sensitivity: lower = bars stay shorter, so only loud sound reaches the top
    property int    sensitivity: 100           // percent. 100 = cava's normal level, 40 = much calmer
    property real   curve: 1                // 1 = linear. Higher squashes quiet sound down further
                                              // while loud sound still reaches full height
    property real   topRadius: 7              // rounding of the top corners only (px); 0 = fully square
    property int    barGap: 4                 // px between bars
    property int    maxHeight: 220            // tallest a bar can get (px); also the window height
    property real   minBar: 3                 // bars never shrink below this (px), so silence still shows a line
    property real   barOpacity: 0.85

    // fade out when nothing is playing
    property real   silenceThreshold: 0.02    // a bar below this (0..1) counts as silent. Raise it if
                                              // background noise keeps the bars from fading out
    property int    silenceHoldMs: 1500       // how long it must stay silent before fading starts
    property int    fadeMs: 800               // how long the fade takes (also used when sound returns)

    // colours sampled from your wallpaper: the bright water highlight and its mid-blue
    property color  barTop: "#49fffe"         // colour at the top of each bar
    property color  barBottom: "#0b79dd"      // colour at the bottom of each bar
    property string inputMethod: "pipewire"   // or "pulse" / "alsa" if your setup needs it

    // latest bar heights from cava, each 0..1
    property var levels: []

    // The cava config is passed in through an environment variable and written to a file at
    // launch, so there is nothing extra to create or keep next to this file.
    function cavaConfig() {
        return [
            "[general]",
            "bars = " + barCount,
            "framerate = 60",
            // autosens off = cava stops boosting quiet music to fill the screen, so the bars
            // reflect how loud things actually are
            "autosens = 0",
            "sensitivity = " + sensitivity,
            "",
            "[input]",
            "method = " + inputMethod,
            "source = auto",
            "",
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = 1000",
            "bar_delimiter = 59",
            "frame_delimiter = 10",
            "channels = mono",
            "mono_option = average",

            "",
            "[smoothing]",
            "monstercat = 1",
            "waves = 0",
        ].join("\n");
    }

    // Silence tracking. `fade` is 1 while sound is playing and glides to 0 when it stops.
    QtObject {
        id: idle
        property double lastLoud: Date.now()
        property bool active: true
        property real fade: active ? 1 : 0

        Behavior on fade {
            NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad }
        }
    }

    // Also covers the case where cava stops sending frames altogether when nothing is playing.
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: idle.active = (Date.now() - idle.lastLoud) < root.silenceHoldMs
    }

    Process {
        id: cava
        running: true
        command: ["sh", "-c",
            'cfg="${XDG_RUNTIME_DIR:-/tmp}/qs-cava.conf"; printf "%s\\n" "$CAVA_CFG" > "$cfg"; exec cava -p "$cfg"']
        environment: ({ CAVA_CFG: root.cavaConfig() })

        // cava prints one line per frame, like "312;540;877;...;"
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split(";");
                const out = [];
                let peak = 0;
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "") continue;
                    const v = Math.min(1, Number(parts[i]) / 1000);
                    out.push(v);
                    if (v > peak) peak = v;
                }
                root.levels = out;

                // any real sound brings the bars back straight away
                if (peak >= root.silenceThreshold) {
                    idle.lastLoud = Date.now();
                    idle.active = true;
                }
            }
        }

        // anything cava complains about shows up in the terminal that launched quickshell
        stderr: SplitParser {
            onRead: data => console.log("cava says: " + data)
        }

        // if cava dies (for example PipeWire restarts) start it again after a moment.
        // exit code 127 means cava isn't installed, so don't loop forever on that.
        onExited: (exitCode, exitStatus) => {
            console.log("cava exited with code " + exitCode);
            if (exitCode !== 127) restartTimer.start();
            else console.log("cava was not found. Install it and make sure it is on your PATH.");
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: cava.running = true
    }

    // one visualiser per monitor, all fed by the same cava process
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { bottom: true; left: true; right: true }
            implicitHeight: root.maxHeight
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore   // don't reserve space or push windows around
            mask: Region {}                       // empty input region = clicks pass straight through

            // Bottom = sits above the wallpaper but behind normal windows, like your clock.
            // Use WlrLayer.Top if you want it drawn over everything (it stays click-through).
            WlrLayershell.layer: WlrLayer.Bottom

            Row {
                anchors.fill: parent
                spacing: root.barGap

                Repeater {
                    model: root.barCount

                    Rectangle {
                        required property int index

                        // how tall the bar looks on screen
                        readonly property real barH: Math.max(root.minBar,
                            Math.pow(root.levels[index] || 0, root.curve) * root.maxHeight)

                        // Only the top is rounded: every corner is rounded, but the rectangle is
                        // made taller by one radius and pushed down so its rounded bottom corners
                        // sit below the bottom edge of the screen, out of sight.
                        readonly property real r: Math.min(root.topRadius, width / 2)

                        width: (parent.width - root.barGap * (root.barCount - 1)) / root.barCount
                        height: barH + r
                        y: parent.height - barH
                        radius: r
                        opacity: root.barOpacity * idle.fade

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.barTop }
                            GradientStop { position: 1.0; color: root.barBottom }
                        }
                    }
                }
            }
        }
    }
}
