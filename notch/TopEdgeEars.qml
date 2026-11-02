import QtQuick

// Concave screen joins shared with the notch's existing expanded shape.
Item {
    id: ears
    property real radius: 6
    property color color: "black"
    height: radius
    Repeater {
        model: 2
        delegate: Canvas {
            id: join
            required property int index
            width: ears.radius + 1
            height: ears.radius
            x: index === 0 ? -ears.radius : ears.width - 1
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: ears; function onColorChanged() { join.requestPaint(); } }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const e = ears.radius;
                if (e <= 0) return;
                ctx.fillStyle = ears.color;
                ctx.beginPath();
                if (index === 0) {
                    ctx.moveTo(e + 1, 0);
                    ctx.lineTo(e + 1, e);
                    ctx.lineTo(e, e);
                    ctx.arc(0, e, e, 0, -Math.PI / 2, true);
                } else {
                    ctx.moveTo(0, 0);
                    ctx.lineTo(0, e);
                    ctx.lineTo(1, e);
                    ctx.arc(1 + e, e, e, Math.PI, 1.5 * Math.PI, false);
                }
                ctx.closePath();
                ctx.fill();
            }
        }
    }
}
