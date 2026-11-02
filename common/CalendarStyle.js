.pragma library

// Weekend colors take priority over meeting markers.
function underlineColor(date, meetingDates) {
    if (date.getDay() === 6) return "#2ba9de";
    if (date.getDay() === 0 || !meetingDates[Qt.formatDate(date, "yyyy-MM-dd")]) return "#f54d39";
    return "transparent";
}
