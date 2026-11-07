.pragma library

// Keep capture delegates alive across metadata and geometry refreshes.
function synchronize(model, entries, key) {
    for (let index = 0; index < entries.length; index++) {
        const identity = String(entries[index][key]);
        let found = index;
        while (found < model.count && model.get(found).identity !== identity) found++;
        if (found === model.count) model.insert(index, { identity: identity, entry: entries[index] });
        else {
            if (found !== index) model.move(found, index, 1);
            if (JSON.stringify(model.get(index).entry) !== JSON.stringify(entries[index]))
                model.setProperty(index, "entry", entries[index]);
        }
    }
    if (model.count > entries.length) model.remove(entries.length, model.count - entries.length);
}
