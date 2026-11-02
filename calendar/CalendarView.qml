import QtQuick
import "CalendarStyle.js" as CalendarStyle
import "MoonPhase.js" as MoonPhase

Item {
    id: calendar
    property date now: new Date()
    property int debugDayOffset: 0
    readonly property date selectedDate: new Date(now.getFullYear(), now.getMonth(), now.getDate() + debugDayOffset, 12)
    readonly property string dayKey: Qt.formatDate(selectedDate, "yyyy-MM-dd")
    readonly property int targetDay: Date.UTC(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate()) / 86400000
    property bool animationReady: false
    property int transitionMs: 650
    property real scrollDay: targetDay
    readonly property int baseDay: Math.floor(scrollDay)
    property real ringProgress: 1
    property int ringCollapseMs: 240
    property int ringExpandMs: 360
    property real rippleProgress: 1
    property int rippleMs: 520
    property real rippleTravel: 44
    property real inactiveDaySpacing: 100
    property real activeDaySpacing: 170
    Component.onCompleted: {
        // Break the target binding so the rings can close before dates start moving.
        scrollDay = targetDay;
        animationReady = true;
    }
    onTargetDayChanged: {
        if (!animationReady) return;
        dateTransition.stop();
        rippleProgress = 1;
        dateScroll.to = targetDay;
        dateTransition.start();
    }
    SequentialAnimation {
        id: dateTransition
        NumberAnimation {
            target: calendar; property: "ringProgress"; to: 0
            duration: calendar.ringCollapseMs; easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            id: dateScroll
            target: calendar; property: "scrollDay"
            duration: calendar.transitionMs; easing.type: Easing.InOutCubic
        }
        ParallelAnimation {
            NumberAnimation {
                target: calendar; property: "ringProgress"; to: 1
                duration: calendar.ringExpandMs; easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                // Slightly delay the ripple while retaining overlap with the outer ring.
                PauseAnimation { duration: Math.round(calendar.ringExpandMs * 0.65) + 40 }
                ScriptAction { script: calendar.rippleProgress = 0; }
                NumberAnimation {
                    target: calendar; property: "rippleProgress"; to: 1
                    duration: calendar.rippleMs; easing.type: Easing.OutQuad
                }
            }
        }
    }
    property string displayFont: "sans-serif"
    property color accent: "#35e6ff"
    property color moonColor: "#ffe500"
    // Calendar sync supplies local dates (yyyy-MM-dd) containing meetings.
    property var meetingDates: ({})
    readonly property real uiScale: Math.min(width / 1440, height / 900)

    // The launcher shares one provider across screens; standalone previews use this one.
    property var moonPhaseSource: localMoonPhases
    MoonPhaseProvider {
        id: localMoonPhases
        dates: {
            if (calendar.moonPhaseSource !== localMoonPhases) return [];
            const result = [];
            for (let i = -6; i <= 6; i++) result.push(calendar.dateForDay(calendar.baseDay + i));
            return result;
        }
    }

    function dateForDay(serial) {
        const utc = new Date(serial * 86400000);
        return new Date(utc.getUTCFullYear(), utc.getUTCMonth(), utc.getUTCDate(), 12);
    }
    function dayAt(offset) { return dateForDay(targetDay + offset); }
    function distanceForDay(offset) {
        // Preserve the selected day's anchor, opening space only around the center.
        const direction = offset < 0 ? -1 : 1;
        const distance = Math.abs(offset);
        return offset * inactiveDaySpacing + direction * (activeDaySpacing - inactiveDaySpacing)
            * Math.sin(Math.min(1, distance) * Math.PI / 2);
    }
    function underlineColor(date) {
        return CalendarStyle.underlineColor(date, meetingDates);
    }

    // Draw against the actual screen, not the letterboxed reference stage.
    Canvas {
        id: timeline
        z: 1
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: stage
            function onXChanged() { timeline.requestPaint(); }
            function onYChanged() { timeline.requestPaint(); }
            function onScaleChanged() { timeline.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const slope = 910 / 1440;
            const intercept = stage.y + 1120 * stage.scale + slope * stage.x;
            ctx.strokeStyle = "rgba(255,255,255,0.88)";
            ctx.lineWidth = 3 * stage.scale;
            ctx.beginPath();
            ctx.moveTo(0, intercept);
            ctx.lineTo(width, intercept - slope * width);
            ctx.stroke();
        }
    }

    Item {
        id: stage
        width: 1440
        height: 900
        scale: calendar.uiScale
        transformOrigin: Item.TopLeft
        x: (calendar.width - width * scale) / 2
        y: (calendar.height - height * scale) / 2

        // Only the selected day's concentric circles remain from the blue band.
        Rectangle {
            x: 830 - width / 2; y: 495 - height / 2
            width: 192 + 2 * calendar.rippleTravel * calendar.rippleProgress
            height: width; radius: width / 2
            color: "transparent"
            border.color: "#4086e8"
            border.width: 9 * (1 - calendar.rippleProgress)
            opacity: 1 - calendar.rippleProgress
            visible: opacity > 0.001
        }
        Rectangle {
            x: 830 - width / 2; y: 495 - height / 2
            width: 192 * calendar.ringProgress; height: width; radius: width / 2
            color: "transparent"
            border.color: "#4086e8"
            border.width: 9 * calendar.ringProgress * calendar.ringProgress
            opacity: calendar.ringProgress
        }
        Rectangle {
            x: 830 - width / 2; y: 495 - height / 2
            width: 96 * calendar.ringProgress; height: width; radius: width / 2
            color: "transparent"
            border.color: "#4086e8"
            border.width: 16 * calendar.ringProgress * calendar.ringProgress
            opacity: calendar.ringProgress
        }

        Rectangle {
            x: 923 - width / 2; y: 598 - height / 2
            width: 64; height: width; radius: width / 2
            color: "#073767"
        }

        Repeater {
            model: 13
            Item {
                id: day
                required property int index
                readonly property int serial: calendar.baseDay + index - 6
                readonly property real offset: serial - calendar.scrollDay
                readonly property real distance: calendar.distanceForDay(offset)
                readonly property date date: calendar.dateForDay(serial)
                readonly property real highlight: Math.max(0, 1 - Math.abs(offset))
                x: 830 + distance - 45
                y: 495 - distance * (98 / 155) - 50
                width: 145; height: 110
                opacity: Math.max(0, Math.min(1, (6 - Math.abs(offset)) / 2))
                Text {
                    id: number
                    x: 17; y: 22
                    width: 56; height: 56
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 32
                    horizontalAlignment: Text.AlignHCenter
                    text: day.date.getDate()
                    color: "white"
                    font.family: calendar.displayFont
                    font.pixelSize: 48
                    font.weight: Font.Bold
                }
                Text {
                    id: weekday
                    x: number.x + number.width + 2
                    y: number.y + number.baselineOffset - baselineOffset - 3
                    text: Qt.formatDate(day.date, "ddd").toUpperCase()
                    color: "white"
                    font.family: calendar.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    font.letterSpacing: 2.5
                }
                Rectangle {
                    x: weekday.x
                    y: weekday.y + weekday.baselineOffset + weekdayInk.tightBoundingRect.y
                       + weekdayInk.tightBoundingRect.height + 1
                    width: weekday.implicitWidth
                    height: 4
                    color: calendar.underlineColor(day.date)
                }
                TextMetrics {
                    id: weekdayInk
                    font: weekday.font
                    text: weekday.text
                }
                Canvas {
                    x: 100; y: 115; width: 76; height: 76
                    property real highlight: day.highlight
                    property color markerColor: calendar.moonColor
                    onMarkerColorChanged: requestPaint()
                    onHighlightChanged: requestPaint()
                    property string phaseName: calendar.moonPhaseSource.phaseName(day.date)
                    property real phase: MoonPhase.phaseForName(phaseName)
                    onPhaseChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cx = width / 2, cy = height / 2;
                        const r = 25;
                        // An outline means the API result is not available yet.
                        if (phase < 0) {
                            ctx.strokeStyle = "#808080";
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.stroke();
                            return;
                        }
                        // Highlight changes the color and surround, preserving each day's phase.
                        const amount = Math.max(0, Math.min(1, highlight));
                        const t = amount * amount * (3 - 2 * amount);
                        function mix(a, b) {
                            return Qt.rgba(a.r + (b.r - a.r) * t,
                                           a.g + (b.g - a.g) * t,
                                           a.b + (b.b - a.b) * t, 1);
                        }
                        const white = Qt.rgba(1, 1, 1, 1);
                        const shade = (176 / 255) * (1 - t);
                        const dark = Qt.rgba(shade, shade, shade, 1);
                        const lit = mix(white, markerColor);
                        const c = Math.cos(2 * Math.PI * phase);
                        // One closed path keeps the glow on the illuminated phase only.
                        function litPath() {
                            const side = phase < 0.5 ? 1 : -1;
                            const edge = side * c * r;
                            const k = 0.55228475;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, -side * Math.PI / 2, side * Math.PI / 2, false);
                            ctx.bezierCurveTo(cx + k * edge, cy + side * r,
                                              cx + edge, cy + side * k * r, cx + edge, cy);
                            ctx.bezierCurveTo(cx + edge, cy - side * k * r,
                                              cx + k * edge, cy - side * r, cx, cy - side * r);
                            ctx.closePath();
                        }

                        ctx.fillStyle = Qt.rgba(5 / 255, 25 / 255, 65 / 255, 0.45 * (1 - t));
                        ctx.beginPath();
                        ctx.arc(cx + 2, cy + 2, r, 0, 2 * Math.PI);
                        ctx.fill();

                        // The navy surround grows with the highlight; its white ring stays fixed.
                        ctx.fillStyle = Qt.rgba(7 / 255, 55 / 255, 103 / 255, 1);
                        ctx.beginPath();
                        ctx.arc(cx, cy, r + 7 * t, 0, 2 * Math.PI);
                        ctx.fill();

                        // Soft yellow halo behind the disc, fading in with the active day.
                        if (t > 0) {
                            ctx.save();
                            ctx.shadowColor = Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.65 * t);
                            ctx.shadowBlur = 10;
                            ctx.fillStyle = lit;
                            litPath();
                            ctx.fill();
                            ctx.restore();
                        }

                        ctx.fillStyle = dark;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.fill();

                        ctx.fillStyle = lit;
                        ctx.beginPath();
                        if (phase < 0.5) ctx.arc(cx, cy, r, -Math.PI / 2, Math.PI / 2, false);
                        else ctx.arc(cx, cy, r, Math.PI / 2, -Math.PI / 2, false);
                        ctx.closePath();
                        ctx.fill();

                        if (Math.abs(c) > 0.0001) {
                            ctx.fillStyle = c > 0 ? dark : lit;
                            ctx.beginPath();
                            ctx.ellipse(cx - r * Math.abs(c), cy - r, 2 * r * Math.abs(c), 2 * r);
                            ctx.fill();
                        }

                        // A soft glow follows the curved boundary between light and dark.
                        const edgeGlow = Math.sqrt(Math.max(0, 1 - c * c)) * t;
                        if (edgeGlow > 0.001) {
                            ctx.save();
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                            ctx.clip();
                            const side = phase < 0.5 ? 1 : -1;
                            const edge = side * c * r;
                            const k = 0.55228475;
                            ctx.beginPath();
                            ctx.moveTo(cx, cy + r);
                            ctx.bezierCurveTo(cx + k * edge, cy + r,
                                              cx + edge, cy + k * r, cx + edge, cy);
                            ctx.bezierCurveTo(cx + edge, cy - k * r,
                                              cx + k * edge, cy - r, cx, cy - r);
                            const glowColor = markerColor;
                            for (const band of [[10, 0.08], [6, 0.12], [3, 0.22], [1, 0.5]]) {
                                ctx.lineWidth = band[0];
                                ctx.strokeStyle = Qt.rgba(glowColor.r, glowColor.g, glowColor.b, band[1] * edgeGlow);
                                ctx.stroke();
                            }
                            ctx.restore();
                        }

                        // Match the clock's inner rim glow without lighting the dark side.
                        if (t > 0) {
                            ctx.save();
                            litPath();
                            ctx.clip();
                            const innerGlow = ctx.createRadialGradient(cx, cy, r * 0.58, cx, cy, r);
                            innerGlow.addColorStop(0, Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0));
                            innerGlow.addColorStop(0.65, Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.06 * t));
                            innerGlow.addColorStop(1, Qt.rgba(markerColor.r, markerColor.g, markerColor.b, 0.32 * t));
                            ctx.fillStyle = innerGlow;
                            ctx.fill();
                            ctx.restore();
                        }

                    }
                }
            }
        }

        Rectangle {
            x: 923 - width / 2; y: 598 - height / 2
            width: 67; height: width; radius: width / 2
            color: "transparent"
            border.color: "white"
            border.width: 3
        }

    }
}
