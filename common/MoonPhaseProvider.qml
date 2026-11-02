import QtQuick
import Quickshell
import Quickshell.Io
import "MoonPhase.js" as MoonPhase

QtObject {
    id: provider
    property var dates: []
    property string cacheName: "calendar"
    property string cachePath: Quickshell.cachePath("moon-phases-" + cacheName + ".json")
    property string apiUrl: "https://aa.usno.navy.mil/api/rstt/oneday"
    property var records: ({})
    property var pending: ({})
    property bool cacheReady: false
    property int activeRequests: 0

    function keyFor(date) {
        return Qt.formatDate(date, "yyyy-MM-dd") + "@" + (-date.getTimezoneOffset() / 60);
    }
    function phaseName(date) { return records[keyFor(date)] || ""; }

    function loadCache() {
        if (cacheReady) return;
        try {
            const data = JSON.parse(cacheFile.text());
            const valid = {};
            if (data.version === 1 && data.phases && typeof data.phases === "object") {
                for (const key of Object.keys(data.phases)) {
                    if (MoonPhase.phaseForName(data.phases[key]) >= 0) valid[key] = data.phases[key];
                }
            }
            records = valid;
        } catch (error) {
            records = {};
        }
        cacheReady = true;
        refresh();
    }
    function refresh() {
        if (!cacheReady) return;
        for (const date of dates) requestDate(date);
    }
    function requestDate(date) {
        const key = keyFor(date);
        if (records[key] !== undefined || pending[key] !== undefined) return;
        if (date.getFullYear() < 1700 || date.getFullYear() > 2100) return;
        const request = new XMLHttpRequest();
        pending[key] = { request: request, started: Date.now() };
        activeRequests++;
        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || pending[key] === undefined) return;
            delete pending[key];
            activeRequests--;
            try {
                if (request.status !== 200) throw new Error("HTTP " + request.status);
                const payload = JSON.parse(request.responseText);
                const data = payload.properties && payload.properties.data;
                if (!data || data.year !== date.getFullYear() || data.month !== date.getMonth() + 1
                    || data.day !== date.getDate() || MoonPhase.phaseForName(data.curphase) < 0)
                    throw new Error("Invalid moon phase response");
                const next = Object.assign({}, records);
                next[key] = data.curphase;
                const keys = Object.keys(next);
                for (let i = 0; i < keys.length - 512; i++) delete next[keys[i]];
                records = next;
                cacheSaver.restart();
            } catch (error) {
                console.warn("Moon phase unavailable for " + key + ": " + error.message);
            }
        };
        // Coordinates are required by the rise/set endpoint; phase needs no user location.
        const url = apiUrl + "?date=" + Qt.formatDate(date, "yyyy-MM-dd")
                    + "&coords=0,0&tz=" + (-date.getTimezoneOffset() / 60);
        request.open("GET", url);
        request.send();
    }
    onDatesChanged: refresh()
    Component.onDestruction: {
        for (const key of Object.keys(pending)) {
            pending[key].request.onreadystatechange = null;
            pending[key].request.abort();
        }
    }

    property FileView cacheFile: FileView {
        path: provider.cachePath
        printErrors: false
        onLoaded: provider.loadCache()
        onLoadFailed: {
            provider.cacheReady = true;
            provider.refresh();
        }
        onSaveFailed: console.warn("Could not save the moon phase cache")
    }
    property Timer cacheSaver: Timer {
        interval: 300
        onTriggered: provider.cacheFile.setText(JSON.stringify({ version: 1, phases: provider.records }))
    }
    property Timer retryTimer: Timer {
        interval: 300000
        running: provider.cacheReady
        repeat: true
        onTriggered: provider.refresh()
    }
    property Timer timeoutTimer: Timer {
        interval: 1000
        running: provider.activeRequests > 0
        repeat: true
        onTriggered: {
            for (const key of Object.keys(provider.pending)) {
                const entry = provider.pending[key];
                if (Date.now() - entry.started < 20000) continue;
                delete provider.pending[key];
                provider.activeRequests--;
                entry.request.onreadystatechange = null;
                entry.request.abort();
                console.warn("Moon phase request timed out for " + key);
            }
        }
    }
}
