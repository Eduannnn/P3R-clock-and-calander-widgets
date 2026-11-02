// Run with: node --test workspaces/tests/motion.test.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { runInNewContext } = require('node:vm');
const { resolve } = require('node:path');
const motion = {};
runInNewContext(readFileSync(resolve(__dirname, '../OverviewMotion.js'), 'utf8'), motion);

test('slow partial swipes return, completed swipes stay open', () => {
    assert.equal(motion.destination(0.3, 0, false, 0), 0);
    assert.equal(motion.destination(0.7, 0, false, 0), 1);
    assert.equal(motion.destination(0.7, 0, false, 1), 1);
    assert.equal(motion.destination(0.3, 0, false, 1), 0);
});

test('short intentional flicks complete in both directions', () => {
    assert.equal(motion.destination(0.2, 3, false, 0), 1);
    assert.equal(motion.destination(0.8, -3, false, 1), 0);
});

test('recent reversal wins over earlier momentum', () => {
    const history = [{ time: 0, position: 0 }, { time: 100, position: 0.8 },
        { time: 140, position: 0.9 }, { time: 180, position: 0.6 }];
    const speed = motion.velocity(history, 190);
    assert.ok(speed < 0);
    assert.equal(motion.destination(0.6, speed, false, 0), 0);
    assert.equal(motion.velocity(history, 300), 0);
    assert.equal(motion.velocity([{ time: 100, position: 0.1 }, { time: 100, position: 0.2 }], 100), 0);
    // The whole gesture can fit inside the velocity window. Its latest
    // direction still wins even when net travel from the start is positive.
    const quickReverse = [{ time: 0, position: 0 }, { time: 20, position: 0.7 }, { time: 40, position: 0.3 }];
    assert.ok(motion.velocity(quickReverse, 60) < 0);
    assert.equal(motion.destination(0.3, motion.velocity(quickReverse, 60), false, 0), 0);
});

test('cancellation restores the original target regardless of momentum', () => {
    assert.equal(motion.destination(0.9, 10, true, 0), 0);
    assert.equal(motion.destination(0.1, -10, true, 1), 1);
});

test('spring is frame-rate independent and settles without overshoot from rest', () => {
    for (const fps of [30, 60, 90, 120, 144]) {
        let state = { position: 0, speed: 0 };
        for (let frame = 0; frame < fps; frame++) {
            state = motion.step(state.position, state.speed, 1, 1 / fps);
            assert.ok(state.position >= 0 && state.position <= 1);
        }
        const exact = motion.step(0, 0, 1, 1);
        assert.ok(Math.abs(state.position - exact.position) < 1e-12);
        assert.ok(Math.abs(state.position - 1) < 1e-6);
    }
});

test('release velocity and interrupted spring position remain continuous', () => {
    const epsilon = 1e-7;
    const first = motion.step(0.25, 2, 1, epsilon);
    assert.ok(Math.abs((first.position - 0.25) / epsilon - 2) < 0.001);
    const moving = motion.step(0.25, 2, 1, 0.04);
    const reversed = motion.step(moving.position, moving.speed, 0, 0);
    assert.equal(reversed.position, moving.position);
    assert.equal(reversed.speed, moving.speed);
    assert.ok(Math.abs(motion.step(moving.position, moving.speed, 0, 5).position) < 1e-12);
});
