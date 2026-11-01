import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: calibration
    property var screen: null
    property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/p3r-widgets/notch.json"
    property var saved: null
    property real compositorScale: 1.5
    property int physicalWidth: 2560
    property int physicalHeight: 1664
    property real driverHeight: 64
    property string error: ""
    property bool saving: false
    property string pendingJson: ""
    property bool configLoaded: false
    property bool displayReady: false
    readonly property bool ready: configLoaded && displayReady
    signal saveCompleted()

    function validRectangle(r) {
        return screen && r && [r.x, r.y, r.width, r.height, r.cornerRadius]
            .every(v => typeof v === "number" && Number.isFinite(v))
            && r.x >= 0 && r.y >= 0 && r.width > 0 && r.height > 0
            && r.x + r.width <= screen.width && r.y + r.height <= screen.height
            && r.cornerRadius >= 0 && r.cornerRadius <= Math.min(r.width, r.height) / 2;
    }

    readonly property bool valid: {
        if (!saved || !screen || saved.version !== 1 || saved.coordinateSpace !== "output-logical") return false;
        const s = saved.screen, r = saved.rect;
        if (!s || !r || s.name !== screen.name || Math.abs(s.compositorScale - compositorScale) > 0.001
            || Math.abs(s.logicalWidth - screen.width) > 1 || Math.abs(s.logicalHeight - screen.height) > 1) return false;
        return validRectangle(r);
    }
    readonly property var rect: valid ? saved.rect : ({ x: 0, y: 0, width: 0, height: 0, cornerRadius: 0 })
    readonly property real padding: valid ? Math.max(0, Number(saved.safetyPadding) || 0) : 0

    function save(rectangle) {
        if (!screen || saving) return;
        if (!validRectangle(rectangle)) { error = "The rectangle must fit the screen and have a valid corner radius."; return; }
        error = "";
        pendingJson = JSON.stringify({
            version: 1,
            coordinateSpace: "output-logical",
            screen: { name: screen.name, logicalWidth: screen.width, logicalHeight: screen.height,
                compositorScale: compositorScale, qtDevicePixelRatio: screen.devicePixelRatio,
                physicalWidth: physicalWidth, physicalHeight: physicalHeight },
            rect: rectangle,
            safetyPadding: 2
        }, null, 4) + "\n";
        saving = true;
        createDirectory.command = ["mkdir", "-p", configPath.slice(0, configPath.lastIndexOf("/"))];
        createDirectory.running = true;
    }
    property Process createDirectory: Process {
        onExited: (code, status) => {
            if (code !== 0) { calibration.error = "Could not create the configuration directory."; calibration.saving = false; return; }
            config.setText(calibration.pendingJson);
        }
    }
    property FileView config: FileView {
        path: calibration.configPath
        printErrors: false
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: {
            try { calibration.saved = JSON.parse(text()); }
            catch (error) { calibration.saved = null; calibration.error = "Invalid notch calibration file."; }
            calibration.configLoaded = true;
        }
        onLoadFailed: { calibration.saved = null; calibration.configLoaded = true; }
        onSaved: {
            calibration.saved = JSON.parse(calibration.pendingJson);
            calibration.saving = false;
            calibration.saveCompleted();
        }
        onSaveFailed: {
            calibration.error = "Could not save notch calibration.";
            calibration.saving = false;
        }
    }
    property Process displayProbe: Process {
        running: true
        command: ["kscreen-doctor", "-j"]
        onExited: calibration.displayReady = true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const output = JSON.parse(text).outputs.find(o => calibration.screen && o.name === calibration.screen.name);
                    if (!output) return;
                    calibration.compositorScale = output.scale;
                    const mode = output.modes.find(m => m.id === output.currentModeId);
                    if (mode) { calibration.physicalWidth = mode.size.width; calibration.physicalHeight = mode.size.height; }
                } catch (error) { console.warn("Could not read compositor display measurements; using calibration defaults."); }
            }
        }
    }
    property Process heightProbe: Process {
        running: true
        command: ["sh", "-c", "for p in /sys/firmware/devicetree/base/soc/dcp@*/apple,notch-height; do if [ -r \"$p\" ]; then od -An -tu4 --endian=big \"$p\"; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const height = Number(text.trim());
                if (height > 0 && height < 300) calibration.driverHeight = height;
            }
        }
    }
}
