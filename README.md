# Quickshell Widgets

A collection of Qt Quick/QML desktop widgets for Linux and Wayland, featuring Persona 3 inspired visuals, animated audio bars, and a notch-style media player. Run all four widgets through one Quickshell instance, or launch them individually.

## Included widgets

| Widget | Description | Main source |
| --- | --- | --- |
| **P3R Clock** | Top-right clock with a hover-to-show date, weekday/weekend banner, animated waves, time-of-day label, and glowing moon glyph. | [`P3R-CLOCK/clock.qml`](P3R-CLOCK/clock.qml) |
| **Calendar** | Transparent, click-through desktop timeline on every screen, with an animated date transition, astronomical moon phases for each date, and a glowing active-day marker. | [`CALENDAR/CalendarView.qml`](CALENDAR/CalendarView.qml) |
| **CAVA** | Full-width audio visualizer along the bottom of the screen, with configurable colors and a fade when audio goes silent. | [`CAVA/cava.qml`](CAVA/cava.qml) |
| **Notch** | Media controls, cover-art-colored audio bars, and Bluetooth/USB device connection notices. | [`NOTCH/notch.qml`](NOTCH/notch.qml) |

The calendar and clock use phase names returned by the [U.S. Naval Observatory API](https://aa.usno.navy.mil/data/api.html), mapping names such as `Full Moon` and `Waning Gibbous` directly to fixed glyph presets. The calendar requests each displayed date, including past and future dates, and the clock requests today. Results are cached across restarts; uncached dates need an internet connection. While a result is unavailable, an outline is shown. The API supports dates from 1700 through 2100. The unlit portion is black on the clock and the calendar's active day, and light gray on other calendar dates.

## Requirements

- An internet connection to fetch uncached moon-phase dates (no API key required).
- A Linux Wayland session with a compositor supporting the layer-shell protocol.
- **Quickshell**, including its Qt Quick, Wayland, I/O, and MPRIS modules and Qt Quick Effects support.
- **CAVA**, installed as `cava` on your `PATH`, for the bottom visualizer and Notch's audio bars.
- An audio backend supported by your CAVA installation. Both audio widgets default to **PipeWire**.
- An **MPRIS-compatible media player** for Notch's track information and controls.
- **Git** to clone the repository, plus standard shell tools including `find` and `readlink`.

The clock and calendar look for Impact, Anton, Bebas Neue, Oswald, Archivo Black, and Arial Black. Install a preferred font for the intended appearance; the calendar falls back to sans-serif.

## Installation

Install Quickshell and CAVA using your distribution's package manager or their upstream installation instructions. No compilation or additional build step is needed for these QML files.

Clone the repository and run the installer as your normal desktop user, **without sudo**:

```sh
git clone https://github.com/Eduannnn/WIDGETS.git
cd WIDGETS
./install.sh
```

The installer:

1. Checks that Quickshell, CAVA, and the systemd user manager are available.
2. Copies the project to `~/.config/quickshell/p3r/`, preserving widget entry-point symlinks and excluding Git and local agent metadata.
3. Creates `p3r-widgets.service` in `${XDG_CONFIG_HOME:-~/.config}/systemd/user/` with the absolute Quickshell executable and your current `PATH`.
4. Imports available desktop display variables, runs `systemctl --user daemon-reload`, and enables the service for `graphical-session.target`.

The installer enables the service without starting it. Stop any existing widget instances, then start it:

```sh
systemctl --user start p3r-widgets.service
```

Automatic startup requires your desktop or compositor to activate `graphical-session.target` and provide its Wayland environment to the systemd user manager. For sessions without that integration, add these commands to the compositor's startup configuration:

```sh
systemctl --user import-environment WAYLAND_DISPLAY
systemctl --user start p3r-widgets.service
```

### Service management

```sh
systemctl --user status p3r-widgets.service  # Check status
journalctl --user -u p3r-widgets.service -f # Follow logs
systemctl --user restart p3r-widgets.service
systemctl --user stop p3r-widgets.service
systemctl --user disable --now p3r-widgets.service
```

Disable previous individual widget services or compositor autostart entries before switching to this service. `--no-duplicate` prevents another instance of the same configuration; it does not stop widgets launched from a different path.

### Run manually or preview one widget

To run all installed widgets in a terminal instead of using the service:

```sh
quickshell --no-duplicate -p ~/.config/quickshell/p3r
```

To preview one widget, stop the service and run the corresponding command from the installed directory:

```sh
systemctl --user stop p3r-widgets.service
cd ~/.config/quickshell/p3r
quickshell -p P3R-CLOCK/clock.qml
quickshell -p CALENDAR
quickshell -p CAVA/cava.qml
quickshell -p NOTCH/notch.qml
```

Run only the command for the widget you want. The same preview commands also work from the repository directory.

### Updating and removing

To update, run these commands from your cloned repository:

```sh
git pull
./install.sh
systemctl --user restart p3r-widgets.service
```

Reinstalling overwrites matching files in the installed copy, including local QML edits. Back up customizations first. Files removed upstream are not automatically deleted from the installed copy.

To remove the installation:

```sh
systemctl --user disable --now p3r-widgets.service
rm -- "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/p3r-widgets.service"
systemctl --user daemon-reload
rm -r -- "$HOME/.config/quickshell/p3r"
```

## Widget configuration

Settings are QML properties inside each widget's source file. For the service installation, edit the files under `~/.config/quickshell/p3r/`; the repository links below identify the corresponding source files. Edit the values directly and save. The combined launcher watches QML sources and helper files and reloads automatically after a short delay. Restart it after adding or disabling widgets.

### P3R Clock

Edit [`P3R-CLOCK/clock.qml`](P3R-CLOCK/clock.qml):

- `anchors` and `margins`: screen placement and distance from the edges.
- `horizontalScale` and `topPad`: proportions and space above the lettering.
- `fontChoices`: preferred display fonts, in priority order.
- `accentCyan`, `moonYellow`, and `ink`: accent, moon, and shadow colors.
- `animateWaves`: enable or freeze the background animation.
- `labelHeight`, `labelBaseline`, and `labelGap`: banner typography.

Hover over the widget to show the date instead of the digital clock.

### Calendar

Edit [`CALENDAR/CalendarView.qml`](CALENDAR/CalendarView.qml) for `moonColor` and `transitionMs` (the date scroll duration in milliseconds). Its layout scales from a 1440 × 900 reference stage to fit each screen.

Edit [`CALENDAR/shell.qml`](CALENDAR/shell.qml) to change the font preference list or date-preview settings. Keep `debugDateCycle: false` and `debugDayOffset: 0` for normal use. Setting `debugDateCycle` to `true` advances the preview date every ten seconds.

#### Outlook / Teams calendar events

The calendar can subscribe to your school's or your own Outlook calendar through its published ICS feed. Teams meetings appear in the corresponding Outlook calendar.

1. In Outlook on the web, open **Settings → Calendar → Shared calendars → Publish a calendar**. Select the calendar and the minimum detail level you need; availability-only is enough for date markers.
2. Publish it and copy the **ICS** subscription link. Keep this link private: anyone who has it can read the details you published.
3. From the repository or installed directory, run:

```sh
./CALENDAR/setup-calendar.sh
```

The setup script compiles the Rust helper once and installs it to `${XDG_DATA_HOME:-~/.local/share}/p3r-widgets/bin/p3r-calendar-sync`. It uses your installed Cargo/Rust toolchain, or `nix-shell` on NixOS; other systems need Rust and a C compiler for the build. The running widgets only need the compiled executable. Paste the ICS link at the hidden prompt on first setup. The running widgets pick up the configuration within ten seconds.

Rerunning setup preserves an existing subscription and migrates older configurations automatically. Use `./CALENDAR/setup-calendar.sh --configure` to replace the subscription link, or `--build-only` to install the helper without changing configuration. Build artifacts stay in the user's cache directory, outside the repository.

The URL is saved outside the repository in `${XDG_CONFIG_HOME:-~/.config}/p3r-widgets/calendar.json` with owner-only access. Calendar data is cached privately under `${XDG_CACHE_HOME:-~/.cache}/p3r-widgets/`. The widget checks for updates every five minutes and uses cached events if the feed is temporarily unavailable; Outlook controls how quickly published changes become available.

Underlines follow these rules:

- **Monday–Friday:** red when there are no calendar events; no underline when there is an event.
- **Saturday:** always blue, regardless of events.
- **Sunday:** always red, regardless of events.

Recurring meetings, moved occurrences, all-day events, and local time zones are supported. Cancelled occurrences are excluded. The clock's day triangle uses the same color as today's underline, falling back to black when there is no underline.

The clock also uses this feed for its school-day labels. A weekday with an event shows “Before School”, “Lunchtime”, and “After School” at the corresponding hours. Weekdays without events and weekends show “Early Morning”, “Midday”, and “Late Afternoon”. Until the calendar has synced, the clock uses these neutral labels. This treats any event in the subscribed school calendar as a school day.

### CAVA visualizer

Edit [`CAVA/cava.qml`](CAVA/cava.qml):

- `bars`, `barGap`, `maxHeight`, and `topRadius`: bar count and shape. Odd bar counts are rounded up to an even number.
- `sensitivity` and `curve`: response to audio levels.
- `barTop`, `barBottom`, and `barOpacity`: appearance.
- `silenceThreshold`, `silenceHoldMs`, and `fadeMs`: silence detection and fading.
- `inputMethod`: audio backend, such as `"pipewire"`, `"pulse"`, or `"alsa"`, depending on your CAVA build.

### Notch media widget

Edit [`NOTCH/notch.qml`](NOTCH/notch.qml):

- `screenName`: target output, initially `"eDP-1"`. The first available screen is used if no output matches.
- `notchWidth` and `notchHeight`: use saved calibration dimensions, falling back to 280 × 37.5 logical pixels before calibration. `wingWidth` controls the side extensions.
- `debugNotch`: show a calibration rectangle while adjusting placement.
- For the physical camera cutout, use the [temporary calibration overlay](NOTCH/CALIBRATION.md). Saved logical coordinates drive the layout's position, dimensions, and no-content zone.
- `debugNotifications`: set to `true` to continuously replay the notification preview; `false` stops it.
- `uiScale`, `animMs`, and `collapseDelayMs`: size and animation timing.
- `accent`, `tintFromCover`, and `fontFamily`: appearance and artwork-based coloring.
- `barCount`: audio bar count. Change the audio backend inside `cavaConfig()` if needed; Notch has its own CAVA configuration.
- `bluetoothNoticeMs`: how long a device notice stays visible, initially 4 seconds.

Play media in an MPRIS-compatible application, then hover over Notch to expand it. Available controls and seeking depend on what the player supports.

Bluetooth controllers, headphones, earbuds, keyboards, mice, and other devices briefly show a white symbol on the left side of the collapsed notch. A reported Bluetooth battery level adds a ring and percentage on the right; the right wing retracts when battery information is unavailable or the device disconnects. Late battery reports update the notice while it is visible. USB controllers and audio devices are detected through `udevadm`, included with systemd. Notices work without media playback, queue when several devices change, and return to the previous media state. Existing Bluetooth connections are not announced at startup. Plain analog headphone jacks are not monitored.

Preview simulated connection and disconnection notices on a running configuration:

```sh
quickshell ipc -p . call notch preview
```

The notice icons use locally extracted SF Symbols from `${XDG_DATA_HOME:-~/.local/share}/icons/SFSymbols/` when available, with system-icon fallbacks. See [the symbol exporter](NOTCH/symbol-export/README.md) to extract your own downloaded font assets. Apple artwork is kept outside this repository.

Both audio widgets generate their CAVA configuration at runtime; there is no separate CAVA configuration file to install.

## Enable, disable, or add widgets

The root [`shell.qml`](shell.qml) loads every immediate subdirectory containing a `shell.qml` entry point. Helper components are not launched independently, and a widget loading error is logged without preventing the others from loading.

To disable a widget without deleting its source, rename its entry point in the installed directory and restart the service:

```sh
cd ~/.config/quickshell/p3r
mv CAVA/shell.qml CAVA/shell.qml.disabled
systemctl --user restart p3r-widgets.service
```

To enable it again:

```sh
cd ~/.config/quickshell/p3r
mv CAVA/shell.qml.disabled CAVA/shell.qml
systemctl --user restart p3r-widgets.service
```

Some entry points are relative symlinks to the widget's main QML file. Preserve those links and their targets when moving or copying files.

To add a widget, create `MyWidget/shell.qml` inside this repository and restart the launcher. Existing `.qml.bak` files are source snapshots and are not loaded as widgets.

## Troubleshooting

- **Nothing appears:** run the launcher from a terminal and check for missing QML modules or layer-shell support. These widgets are intended for Wayland.
- **Duplicate widgets:** stop older individual launches or autostart services, then start the combined launcher once.
- **No audio bars:** confirm `cava` is on `PATH`, play audio, and check that each widget's configured audio backend matches your setup.
- **Notch has no track information:** use a player with MPRIS support. Enable its media integration if required.
- **Notch appears on the wrong screen:** set `screenName` to your output's name and adjust the notch dimensions.
- **Text is clipped or looks different:** install a preferred display font, then adjust the relevant font and layout properties.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding guidelines, verification steps, and pull request expectations.

## AI disclosure

This project was partly AI-assisted, alongside my own development and design work.
