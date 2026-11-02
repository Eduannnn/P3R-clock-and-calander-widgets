import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: events
    property string startDate: ""
    property string endDate: ""
    property var meetingDates: ({})
    property bool configured: false
    property bool stale: false
    property bool hasSynced: false
    property string helper: ""
    property bool refreshQueued: false
    property string activeRange: ""
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME")
        || Quickshell.env("HOME") + "/.config") + "/p3r-widgets/calendar.json"

    function refresh() {
        if (!configured || !startDate || !endDate) return;
        if (sync.running) { refreshQueued = true; return; }
        activeRange = startDate + "/" + endDate;
        sync.command = [helper, "sync", "--start", startDate, "--end", endDate];
        sync.running = true;
    }
    onStartDateChanged: Qt.callLater(refresh)
    onEndDateChanged: Qt.callLater(refresh)

    property FileView settings: FileView {
        path: events.configPath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const config = JSON.parse(text());
                if (typeof config.helper !== "string" || !config.helper.startsWith("/")
                    || typeof config.ics_url !== "string") throw new Error("Invalid config");
                events.helper = config.helper;
                events.configured = true;
                events.refresh();
            } catch (error) {
                events.configured = false;
                events.meetingDates = {};
                console.warn("Invalid private calendar configuration");
            }
        }
        onLoadFailed: {
            events.configured = false;
            events.meetingDates = {};
        }
    }
    property Process sync: Process {
        stdout: SplitParser {
            onRead: line => {
                if (events.activeRange !== events.startDate + "/" + events.endDate) return;
                try {
                    const result = JSON.parse(line);
                    if (!result.meetingDates || typeof result.meetingDates !== "object") return;
                    events.meetingDates = result.meetingDates;
                    events.stale = result.stale === true;
                    events.hasSynced = true;
                } catch (error) {
                    console.warn("Invalid calendar sync result");
                }
            }
        }
        stderr: SplitParser { onRead: line => console.warn(line) }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) console.warn("Calendar sync unavailable; keeping previous meeting dates");
            if (events.refreshQueued) {
                events.refreshQueued = false;
                Qt.callLater(events.refresh);
            }
        }
    }
    property Timer refreshTimer: Timer {
        interval: 300000
        running: events.configured
        repeat: true
        onTriggered: events.refresh()
    }
    property Timer configTimer: Timer {
        interval: 10000
        running: !events.configured
        repeat: true
        onTriggered: events.settings.reload()
    }
}
