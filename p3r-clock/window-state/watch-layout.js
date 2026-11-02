// Read visible window bounds only; never alter focus or window geometry.
(function () {
    const service = SERVICE_NAME;
    let last = "";
    function publish() {
        const windows = [];
        if (!workspace.showingDesktop) workspace.windowList().forEach(function (window) {
            if (window.minimized || window.hidden === true || window.desktopWindow || window.dock) return;
            // KWin labels unnamed layer-shell widgets as normal windows too.
            // Exclude desktop surfaces, including this clock, from occluders.
            if (String(window).indexOf("LayerShellV1Window(") >= 0) return;
            if (window.desktops.length && window.desktops.indexOf(workspace.currentDesktop) < 0) return;
            if (window.activities.length && window.activities.indexOf(workspace.currentActivity) < 0) return;
            const frame = window.frameGeometry;
            if (frame.width > 0 && frame.height > 0) windows.push({
                x: frame.x, y: frame.y, width: frame.width, height: frame.height
            });
        });
        const state = JSON.stringify(windows);
        if (state === last) return;
        last = state;
        callDBus(service, "/Layout", "org.p3r.ClockWindowState", "Update", state);
    }
    function observe(window) {
        ["frameGeometryChanged", "minimizedChanged", "hiddenChanged", "outputChanged", "desktopsChanged", "activitiesChanged"].forEach(function (name) {
            if (window[name]) window[name].connect(publish);
        });
    }
    workspace.windowList().forEach(observe);
    workspace.windowAdded.connect(function (window) { observe(window); publish(); });
    workspace.windowRemoved.connect(publish);
    workspace.windowActivated.connect(publish);
    workspace.currentDesktopChanged.connect(publish);
    workspace.currentActivityChanged.connect(publish);
    if (workspace.showingDesktopChanged) workspace.showingDesktopChanged.connect(publish);
    publish();
})();
