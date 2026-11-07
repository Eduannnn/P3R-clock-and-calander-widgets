import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../common" as Common
import "WorkspaceOrder.js" as Order
import "OverviewMotion.js" as Motion
import "StableModel.js" as Stable
import "../notch" as Notch
import "../indicator" as Indicator

ShellRoot {
    id: overview
    property bool opened: false
    Binding { target: Common.NotchPanels; property: "overviewVisible"; value: win.visible }
    Binding { target: Common.NotchPanels; property: "overviewLeft"; value: drawer.x }
    Binding { target: Common.NotchPanels; property: "overviewProgress"; value: drawer.progress }
    property real reveal: 0
    property bool tracking: false
    property bool settling: false
    property real releaseSpeed: 0
    property real gestureStart: 0
    property int gestureOrigin: 0
    property real gestureTravel: 0
    property var samples: []
    property var workspaces: []
    ListModel { id: workspaceModel; dynamicRoles: true }
    property var clients: []
    property var monitors: []
    property int activeWorkspace: 1
    property string message: ""
    property bool pointerBusy: false
    property bool dragging: false
    property var dragSource: null
    property point pointerStart: Qt.point(0, 0)
    readonly property bool busy: action.running
    readonly property int nextWorkspace: Math.max(0, ...workspaces.map(workspace => workspace.id)) + 1

    function open() {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return;
        message = "";
        settleTo(1, releaseSpeed);
        refresh();
        Qt.callLater(() => keyHandler.forceActiveFocus());
    }
    function close() { cancelDrag(); settleTo(0, releaseSpeed); }
    function settleTo(target, speed) {
        tracking = false;
        opened = target === 1;
        releaseSpeed = speed;
        settling = true;
    }
    function gesture(phase, time, delta, cancelled) {
        if (phase === "start") {
            cancelDrag();
            gestureOrigin = opened ? 1 : 0;
            settling = false;
            tracking = true;
            gestureStart = reveal;
            gestureTravel = 0;
            samples = [{ time: time, position: reveal }];
            refresh();
        } else if (phase === "update" && tracking) {
            gestureTravel -= delta / 180;
            reveal = Motion.clamp(gestureStart + gestureTravel, 0, 1);
            samples = samples.filter(sample => time - sample.time <= 80)
                .concat([{ time: time, position: reveal }]);
            releaseSpeed = Motion.velocity(samples, time);
        } else if (phase === "finish" && tracking) {
            const speed = Motion.velocity(samples, time);
            settleTo(Motion.destination(reveal, speed, cancelled, gestureOrigin), speed);
            if (opened) Qt.callLater(() => keyHandler.forceActiveFocus());
        }
    }
    function refresh() { spacesQuery.refresh(); clientsQuery.refresh(); monitorsQuery.refresh(); }
    function synchronize() {
        if (pointerBusy || busy) return;
        workspaces = spacesQuery.result.filter(workspace => workspace.id > 0).sort((a, b) => a.id - b.id);
        Stable.synchronize(workspaceModel, workspaces, "id");
        clients = clientsQuery.result;
        monitors = monitorsQuery.result;
        const focused = monitors.find(monitor => monitor.focused);
        if (focused) {
            activeWorkspace = focused.activeWorkspace ? focused.activeWorkspace.id : 1;
            const screen = Quickshell.screens.find(screen => screen.name === focused.name);
            if (screen) win.screen = screen;
        }
    }
    function monitorFor(id) { return monitors.find(monitor => monitor.id === id) || monitors[0] || null; }
    function execute(lua) {
        if (busy || !lua) return;
        message = "";
        action.reply = "";
        action.command = ["hyprctl", "eval", lua];
        action.running = true;
    }
    function activateWorkspace(id) {
        if (!Number.isInteger(id) || id <= 0 || busy) return;
        execute("local r=hl.dispatch(hl.dsp.focus({workspace=" + id + "})); assert(r.ok,r.error)");
        close();
    }
    function createWorkspace() {
        if (busy) return;
        const id = nextWorkspace;
        execute("hl.workspace_rule({workspace=\"" + id + "\",persistent=true}); "
            + "local r=hl.dispatch(hl.dsp.focus({workspace=" + id + "})); assert(r.ok,r.error)");
        close();
    }
    function reorder(source, target) {
        if (source === target) return;
        try { execute(Order.reorderLua(Order.movePlan(workspaces.map(workspace => workspace.id), source, target))); }
        catch (error) { message = error.message; }
    }
    function deleteWorkspace(id) {
        if (busy || !Number.isInteger(id) || id <= 1) return;
        cancelDrag();
        execute(Order.deleteLua(id));
    }
    function beginPointer(source, area, mouse) {
        if (busy) return;
        pointerBusy = true;
        dragSource = source;
        pointerStart = area.mapToItem(win.contentItem, mouse.x, mouse.y);
        ghost.x = pointerStart.x - ghost.width / 2;
        ghost.y = pointerStart.y - ghost.height / 2;
    }
    function movePointer(area, mouse) {
        if (!pointerBusy || !dragSource) return;
        const point = area.mapToItem(win.contentItem, mouse.x, mouse.y);
        if (!dragging && Math.hypot(point.x - pointerStart.x, point.y - pointerStart.y) > 8) dragging = true;
        ghost.x = point.x - ghost.width / 2;
        ghost.y = point.y - ghost.height / 2;
    }
    function endPointer() {
        const moved = dragging;
        if (moved) ghost.Drag.drop();
        dragging = false;
        pointerBusy = false;
        dragSource = null;
        return moved;
    }
    function cancelDrag() {
        if (dragging) ghost.Drag.cancel();
        dragging = false;
        pointerBusy = false;
        dragSource = null;
    }

    Common.HyprlandQuery { id: spacesQuery; request: "j/workspaces"; onResultChanged: overview.synchronize() }
    Common.HyprlandQuery { id: clientsQuery; request: "j/clients"; onResultChanged: overview.synchronize() }
    Common.HyprlandQuery { id: monitorsQuery; request: "j/monitors"; onResultChanged: overview.synchronize() }
    Notch.NotchCalibration { id: calibration; screen: win.screen }
    // Refresh on compositor changes, coalesced once per event-loop turn.
    // No timer, subprocess, or JSON geometry query runs for gesture updates.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "custom") {
                const fields = event.data.split(",");
                if (fields[0] === "p3r-overview" && fields.length === 5)
                    overview.gesture(fields[1], Number(fields[2]), Number(fields[3]), fields[4] === "1");
            } else if ((overview.opened || overview.tracking) && /^(workspace|focusedmon|createworkspace|destroyworkspace|moveworkspace|renameworkspace|openwindow|closewindow|movewindow|activewindow|fullscreen|changefloatingmode|windowtitle|monitoradded|monitorremoved|configreloaded)/.test(event.name)) {
                Qt.callLater(overview.refresh);
            }
        }
    }
    FrameAnimation {
        running: overview.settling
        onTriggered: {
            const target = overview.opened ? 1 : 0;
            const next = Motion.step(overview.reveal, overview.releaseSpeed, target, frameTime);
            overview.reveal = next.position;
            overview.releaseSpeed = next.speed;
            if (Math.abs(next.position - target) < 0.001 && Math.abs(next.speed) < 0.01) {
                overview.reveal = target;
                overview.releaseSpeed = 0;
                overview.settling = false;
            }
        }
    }
    Process {
        id: action
        property string reply: ""
        stdout: StdioCollector { onStreamFinished: action.reply = text }
        onExited: (code, status) => {
            if (code !== 0 || /(^|\n)error:/i.test(reply)) overview.message = "Couldn't complete that change. Workspace state has been refreshed.";
            overview.refresh();
        }
    }
    IpcHandler {
        target: "workspaces"
        function open(): void { overview.open(); }
        function close(): void { overview.close(); }
        function toggle(): void { if (overview.opened) overview.close(); else overview.open(); }
        function status(): string {
            return JSON.stringify({ opened: overview.opened, tracking: overview.tracking,
                settling: overview.settling, progress: overview.reveal,
                width: drawer.finalWidth, contentWidth: desktops.implicitWidth + 28,
                desktops: overview.workspaces.length });
        }
    }

    PanelWindow {
        id: win
        visible: overview.opened || overview.tracking || overview.settling || overview.reveal > 0.001
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "p3r-workspaces"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        // The transparent area dismisses the drawer when clicking away.
        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: overview.close()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_LaunchA || event.key === Qt.Key_TaskPane) {
                    overview.close(); event.accepted = true;
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: overview.close()
            }
            Rectangle {
                id: drawer
                readonly property real progress: Motion.clamp(overview.reveal, 0, 1)
                readonly property real topBand: calibration.valid ? calibration.rect.y + calibration.rect.height : 38
                readonly property real collapsedWidth: (calibration.valid ? calibration.rect.width : 208) + 50
                readonly property real finalWidth: Math.min(win.width - 32, Math.max(collapsedWidth, desktops.implicitWidth + 28))
                readonly property real finalHeight: topBand + 196 + (overview.message ? 24 : 0)
                width: collapsedWidth + (finalWidth - collapsedWidth) * progress
                height: topBand + (finalHeight - topBand) * progress
                x: (calibration.valid ? calibration.rect.x + calibration.rect.width / 2 : win.width / 2)
                    - 25 * (1 - progress) - width / 2
                y: 0
                color: "black"
                radius: 18; topLeftRadius: 0; topRightRadius: 0
                clip: true
                MouseArea { anchors.fill: parent }
                Indicator.ConnectionIndicator {
                    // Follow the notch's existing spring into the header. A
                    // sibling of the drawer stays visible outside its clip.
                    parent: keyHandler
                    x: Common.NotchPanels.indicatorX
                    y: Common.NotchPanels.indicatorY
                    width: Common.NotchPanels.indicatorSize; height: width
                    visible: overview.opened || overview.tracking || overview.settling
                    z: 5
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            overview.close();
                            Quickshell.execDetached(["quickshell", "ipc", "-p", Quickshell.shellDir,
                                "call", "controlCenter", "toggle"]);
                        }
                    }
                }
                Flickable {
                    id: desktopStrip
                    y: drawer.topBand + 8
                    // Keep previews at their final size; reveal by clipping
                    // instead of reflowing them during the gesture.
                    width: drawer.finalWidth - 28; height: 176
                    anchors.horizontalCenter: parent.horizontalCenter
                    contentWidth: Math.max(width, desktops.implicitWidth)
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: desktops
                        spacing: 12
                        x: Math.max(0, (desktopStrip.width - implicitWidth) / 2)
                        Repeater {
                            model: workspaceModel
                            delegate: WorkspaceCard {
                                required property var entry
                                width: 206
                                workspace: entry
                                controller: overview
                            }
                        }
                        Rectangle {
                            width: 76; height: 172; radius: 12
                            color: "#18181e"
                            border { color: "#737d91"; width: 1 }
                            Column {
                                anchors.centerIn: parent; spacing: 6
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+"; color: "white"; font.pixelSize: 38 }
                                Text { text: "New"; color: "#b7bfce"; font.pixelSize: 12 }
                            }
                            MouseArea { anchors.fill: parent; onClicked: overview.createWorkspace() }
                        }
                    }
                }
                Text {
                    x: 14; y: drawer.topBand + 186; width: parent.width - 28
                    visible: overview.message !== ""
                    text: overview.message
                    color: "#ffbe9e"; font.pixelSize: 11; elide: Text.ElideRight
                }
            }
            Notch.TopEdgeEars {
                x: drawer.x; y: drawer.y; width: drawer.width
                radius: 6
            }
        }
        Rectangle {
            id: ghost
            z: 100
            width: 170; height: 42; radius: 9
            color: "#ed273b69"; border.color: "#8ce7ff"
            visible: overview.dragging
            Drag.active: overview.dragging
            Drag.source: overview.dragSource
            Drag.keys: overview.dragSource ? [overview.dragSource.dragKind] : []
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            Text {
                anchors.centerIn: parent
                text: overview.dragSource && overview.dragSource.dragKind === "workspace"
                    ? "Desktop " + overview.dragSource.workspaceId : "Move window"
                color: "white"; font.pixelSize: 13
            }
        }
    }
}
