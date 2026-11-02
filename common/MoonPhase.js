.pragma library

// Exact API names select fixed glyph shapes; no illumination thresholds.
function phaseForName(name) {
    const phases = {
        "New Moon": 0,
        "Waxing Crescent": 0.125,
        "First Quarter": 0.25,
        "Waxing Gibbous": 0.375,
        "Full Moon": 0.5,
        "Waning Gibbous": 0.625,
        "Last Quarter": 0.75,
        "Third Quarter": 0.75,
        "Waning Crescent": 0.875
    };
    return Object.prototype.hasOwnProperty.call(phases, name) ? phases[name] : -1;
}
