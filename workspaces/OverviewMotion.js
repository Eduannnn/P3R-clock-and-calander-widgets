// Normalized progress per second. Only the drawer uses this model; workspace
// movement is owned by Hyprland's native swipe implementation.
function clamp(value, minimum, maximum) { return Math.max(minimum, Math.min(maximum, value)); }

function velocity(samples, now) {
    const recent = samples.filter(sample => now - sample.time <= 80);
    if (recent.length < 2) return 0;
    const last = recent[recent.length - 1];
    const direction = Math.sign(last.position - recent[recent.length - 2].position);
    if (direction === 0) return 0;
    // Never average across a reversal: old outward momentum must not turn
    // a deliberate return movement into an unintended open/close.
    let start = recent.length - 2;
    while (start > 0 && Math.sign(recent[start].position - recent[start - 1].position) === direction) start--;
    const first = recent[start];
    return last.time > first.time ? (last.position - first.position) * 1000 / (last.time - first.time) : 0;
}

function destination(position, speed, cancelled, origin) {
    if (cancelled) return origin;
    // A short look ahead makes an intentional flick count while a paused,
    // incomplete swipe returns. Signed velocity makes reversals decisive.
    return position + speed * 0.22 >= 0.5 ? 1 : 0;
}

function step(position, speed, target, seconds) {
    // Exact solution of a critically damped spring: stable at any frame rate,
    // continuous in both position and velocity, and interruptible every frame.
    const omega = 22;
    const time = Math.max(0, seconds);
    const displacement = position - target;
    const coefficient = speed + omega * displacement;
    const decay = Math.exp(-omega * time);
    return {
        position: target + (displacement + coefficient * time) * decay,
        speed: (speed - omega * coefficient * time) * decay
    };
}
