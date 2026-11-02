# Contributing

Contributions to the widgets, documentation, and installation scripts are welcome. Keep each change focused and follow the existing style.

## Report an issue

Describe what happened, what you expected, and how to reproduce it. Include your compositor, Quickshell version, screen resolution and scaling, and relevant terminal output. For visual problems, attach a screenshot or short recording. For moon-phase problems, include the date and time zone.

## Development setup

Install the dependencies listed in [README.md](README.md), then run the QML widgets directly from your clone. The optional calendar-event helper is compiled separately by `calendar/setup-calendar.sh`.

```sh
quickshell --no-duplicate -p .
```

To preview a single widget:

```sh
quickshell -p calendar
quickshell -p p3r-clock/clock.qml
quickshell -p cava/cava.qml
quickshell -p notch/notch.qml
```

Run only the preview you need. Stop existing copies of that widget first to avoid duplicates. If using the installed service, stop it with `systemctl --user stop p3r-widgets.service`.

## Project layout and style

- Widget code lives in `calendar/`, `p3r-clock/`, `cava/`, and `notch/`.
- `common/` contains shared calendar styling, event integration, and moon-phase API code. Preserve relative symlinks to shared helpers and widget entry points.
- The root `shell.qml` discovers widget entry points and watches source files for reloads.
- Use four-space indentation, camelCase properties and functions, and PascalCase reusable QML component filenames. Use semicolons in JavaScript blocks.
- Put configurable colors, dimensions, and timings in properties. Repaint Canvas elements when their drawing inputs change.
- Preserve existing `.qml.bak` snapshots unless the change specifically concerns those backups.

## Verify changes

No automated QML test framework, formatter configuration, or coverage target is currently provided. Launch affected widgets and check Quickshell output for QML errors. Check relevant states, including screen scaling, transitions, scrolling text, playback, and silence.

The calendar helper is Rust source under `calendar/calendar-sync/`. Use Cargo to run its tests and checks:

```sh
cargo test --locked --manifest-path calendar/calendar-sync/Cargo.toml
cargo fmt --check --manifest-path calendar/calendar-sync/Cargo.toml
cargo clippy --locked --all-targets --manifest-path calendar/calendar-sync/Cargo.toml -- -D warnings
```

Use synthetic calendars in tests and keep real subscription URLs and event details outside the repository. After editing Rust code, rerun `./calendar/setup-calendar.sh` to rebuild and install the helper; QML reloads do not compile Rust sources.

For moon-phase changes, verify API-name mappings, date rollover, cached results, and unavailable responses. Preserve the API's classification when choosing presets.

For shell script changes, run `bash -n install.sh`. Run `git diff --check` before submitting. Test installer behavior in an isolated setup to avoid overwriting desktop customizations.

## Submit a pull request

Use a concise imperative commit subject, such as `Fix compact waveform spacing`. Explain the problem, resulting behavior, and validation performed. Link relevant issues and include before-and-after screenshots for visual changes. Avoid unrelated formatting or generated files.
