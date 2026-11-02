// Keep UI rounding from reporting silence for a nonzero output level.
function percentage(level) {
    const value = Math.max(0, Math.min(1, Number.isFinite(level) ? level : 0));
    return value === 0 ? 0 : Math.max(1, Math.round(value * 100));
}

function sliderLevel(level) {
    return Math.round(Math.max(0, Math.min(1, level)) * 100) / 100;
}
