const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { resolve } = require('node:path');
const { runInNewContext } = require('node:vm');

const stable = {};
runInNewContext(readFileSync(resolve(__dirname, '../StableModel.js'), 'utf8')
    .replace(/^\.pragma library\s*/, ''), stable);

function model() {
    const rows = [];
    return {
        get count() { return rows.length; },
        get(index) { return rows[index]; },
        insert(index, row) { rows.splice(index, 0, { ...row }); },
        move(from, to) { rows.splice(to, 0, rows.splice(from, 1)[0]); },
        setProperty(index, key, value) { rows[index][key] = value; },
        remove(index, count) { rows.splice(index, count); }
    };
}

test('metadata updates preserve the window row used by a live capture', () => {
    const windows = model();
    stable.synchronize(windows, [{ address: 'a', title: 'Before' }], 'address');
    const retained = windows.get(0);
    stable.synchronize(windows, [{ address: 'a', title: 'After' }], 'address');
    assert.equal(windows.get(0), retained);
    assert.equal(windows.get(0).entry.title, 'After');
});

test('reordering and removal retain surviving capture rows', () => {
    const windows = model();
    stable.synchronize(windows, [{ address: 'a' }, { address: 'b' }], 'address');
    const a = windows.get(0), b = windows.get(1);
    stable.synchronize(windows, [{ address: 'b' }, { address: 'a' }], 'address');
    assert.equal(windows.get(0), b);
    assert.equal(windows.get(1), a);
    stable.synchronize(windows, [{ address: 'a' }], 'address');
    assert.equal(windows.count, 1);
    assert.equal(windows.get(0), a);
});
