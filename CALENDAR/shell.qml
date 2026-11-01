import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    id: root
    // Temporary preview: set false to return to the real date.
    property bool debugDateCycle: false
    property int debugDayOffset: 0
    onDebugDateCycleChanged: { if (!debugDateCycle) debugDayOffset = 0; }
    Timer {
        interval: 15000
        repeat: true
        running: root.debugDateCycle
        onTriggered: root.debugDayOffset++
    }
    SystemClock { id: clock; precision: SystemClock.Seconds }

    readonly property string selectedDayKey: Qt.formatDate(
        new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate() + debugDayOffset, 12),
        "yyyy-MM-dd")
    function dateAtOffset(offset) {
        const parts = selectedDayKey.split("-").map(Number);
        return new Date(parts[0], parts[1] - 1, parts[2] + offset, 12);
    }
    CalendarEvents {
        id: calendarEvents
        startDate: Qt.formatDate(root.dateAtOffset(-6), "yyyy-MM-dd")
        endDate: Qt.formatDate(root.dateAtOffset(7), "yyyy-MM-dd")
    }
    MoonPhaseProvider {
        id: moonPhases
        dates: {
            const parts = root.selectedDayKey.split("-").map(Number);
            const result = [];
            for (let i = -6; i <= 6; i++)
                result.push(new Date(parts[0], parts[1] - 1, parts[2] + i, 12));
            return result;
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            CalendarView {
                anchors.fill: parent
                now: clock.date
                moonPhaseSource: moonPhases
                meetingDates: calendarEvents.meetingDates
                debugDayOffset: root.debugDayOffset
                displayFont: {
                    const installed = Qt.fontFamilies();
                    for (const name of ["Impact", "Anton", "Bebas Neue", "Oswald", "Archivo Black", "Arial Black"])
                        if (installed.indexOf(name) >= 0) return name;
                    return "sans-serif";
                }
            }
        }
    }
}
