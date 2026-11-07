const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { test } = require('node:test');
const vm = require('node:vm');

const identity = vm.createContext({});
vm.runInContext(readFileSync(`${__dirname}/../MediaIdentity.js`, 'utf8')
    .replace(/^\.pragma library\s*/, ''), identity);

function player(overrides = {}) {
    return {
        dbusName: 'org.mpris.MediaPlayer2.browser',
        uniqueId: 1,
        trackTitle: 'Video', trackArtist: 'Channel', trackAlbum: '',
        metadata: { 'xesam:url': 'https://www.youtube.com/watch?v=abc' },
        ...overrides
    };
}

test('metadata ID churn and title updates within a video do not announce it again', () => {
    const before = identity.snapshot(player());
    const after = identity.snapshot(player({ uniqueId: 3, trackTitle: 'Updated title' }));
    assert.equal(identity.sameTrack(before, after), true);
});

test('YouTube timestamps, playlists and short links identify the same video', () => {
    const before = identity.snapshot(player());
    for (const url of [
        'https://www.youtube.com/watch?list=playlist&v=abc&t=70',
        'https://youtu.be/abc?si=tracking'
    ]) {
        assert.equal(identity.sameTrack(before,
            identity.snapshot(player({ metadata: { 'xesam:url': url } }))), true);
    }
});

test('a different video still announces even with the same title', () => {
    assert.equal(identity.sameTrack(identity.snapshot(player()),
        identity.snapshot(player({ metadata: { 'xesam:url': 'https://www.youtube.com/watch?v=def' } }))), false);
});

test('missing URLs and player object replacement do not reannounce identical content', () => {
    const before = identity.snapshot(player({ metadata: {} }));
    assert.equal(identity.sameTrack(before, identity.snapshot(player({ uniqueId: 9 }))), true);
    assert.equal(identity.sameTrack(before,
        identity.snapshot(player({ metadata: {}, trackTitle: 'Next video' }))), false);
});

test('different media applications remain distinct', () => {
    assert.equal(identity.sameTrack(identity.snapshot(player()),
        identity.snapshot(player({ dbusName: 'org.mpris.MediaPlayer2.music' }))), false);
});

test('Shorts title changes are recognised even while the page URL is stale', () => {
    const metadata = { 'xesam:url': 'https://www.youtube.com/shorts/abc' };
    const before = identity.snapshot(player({ metadata }));
    const after = identity.snapshot(player({ metadata, trackTitle: 'Next Short' }));
    assert.equal(identity.sameTrack(before, after), false);
    assert.equal(identity.sameTrack(after,
        identity.snapshot(player({ metadata, trackTitle: 'Next Short', uniqueId: 7 }))), true);
    assert.equal(identity.sameTrack(after, identity.snapshot(player({
        metadata: { 'xesam:url': 'https://www.youtube.com/shorts/def' },
        trackTitle: 'Next Short'
    }))), true, 'a delayed URL update must not cause a second peek');
});

test('frequent metadata events cannot keep postponing the pending peek', () => {
    // Exercise the actual QML scheduling function with a timer stand-in.
    const qml = readFileSync(`${__dirname}/../notch.qml`, 'utf8');
    const schedule = qml.match(/function scheduleTrackPeek\(\) \{([\s\S]*?)\n    \}/)[1];
    const timer = {
        running: false, starts: 0,
        start() { this.running = true; this.starts++; },
        restart() { this.starts++; }
    };
    const context = vm.createContext({ trackWatchingReady: true, trackChangeTimer: timer });
    for (let i = 0; i < 50; i++) vm.runInContext(schedule, context);
    assert.equal(timer.starts, 1);
    timer.running = false;
    vm.runInContext(schedule, context);
    assert.equal(timer.starts, 2);
});
