# Quickshell Widgets

A collection of Qt Quick/QML desktop widgets for Linux and Wayland, featuring Persona 3 inspired visuals, animated audio bars, and a notch-style media player. Run the widgets through one Quickshell instance, or launch them individually.

## Included widgets

| Widget | Description | Main source |
| --- | --- | --- |
| **P3R Clock** | Top-right clock with a hover-to-show date, weekday/weekend banner, animated waves, time-of-day label, and glowing moon glyph. | [`p3r-clock/clock.qml`](p3r-clock/clock.qml) |
| **Calendar** | Transparent, click-through desktop timeline on every screen, with an animated date transition, astronomical moon phases for each date, and a glowing active-day marker. | [`calendar/CalendarView.qml`](calendar/CalendarView.qml) |
| **CAVA** | Full-width audio visualizer along the bottom of the screen, with configurable colors and a fade when audio goes silent. | [`cava/cava.qml`](cava/cava.qml) |
| **Notch** | Media controls, device notices, a leading Wi-Fi/battery indicator, and an attached Control Center. | [`notch/notch.qml`](notch/notch.qml) |
| **Desktop overview** | Live desktop previews expand from the notch; click to switch and drag headers to reorder desktops. | [`workspaces/shell.qml`](workspaces/shell.qml) |
| **Taskbar** | Solid black strip at notch height, visible while an application is on the current workspace and screen. | [`taskbar/taskbar.qml`](taskbar/taskbar.qml) |
| **Screenshot preview** | Bottom-right thumbnail with a white border and right-click actions: Copy, Save to…, Share…, and Delete. | [`screenshot/screenshot.qml`](screenshot/screenshot.qml) |

The Wi-Fi/battery indicator is part of the notch's leading edge. Its components live in `indicator/`; that folder's standalone launcher is disabled. Wi-Fi status requires NetworkManager's `nmcli`; battery status uses UPower.

Click the indicator to open the black, notch-attached Control Center with dark-gray sections; click outside or press Escape to close it. The Wi-Fi and Bluetooth icons toggle their radios, while the tiles reveal connection settings. Wi-Fi network selection opens `nmtui-connect` in Kitty; Bluetooth pairing opens Blueman, with saved devices available directly in the menu. Display and sound sliders use `brightnessctl` and PipeWire; clicking the speaker toggles mute. Media controls use MPRIS. The panel requires Quickshell's Bluetooth, PipeWire, and MPRIS modules; the Wi-Fi controls use your existing NetworkManager backend.

In the accompanying Hyprland configuration, three-finger horizontal swipes change desktops, swiping up opens the desktop-preview drawer, and swiping down closes it. The MacBook Mission Control media key and `SUPER+TAB` toggle it. Click a preview to switch desktops, drag a desktop header onto another to reorder them, or use `+` to create a desktop. Window tiling is preserved during reordering; numbered workspace shortcuts follow the new order. The drawer only catches pointer input within its own bounds, leaving the real desktop usable. Control Center and the desktop drawer use the notch's existing 6px curved screen joins.

Focus toggles Mako's `do-not-disturb` mode, hiding notification popups while enabled. The media card appears only during active playback and disappears when playback pauses or stops.

The power button beside the battery reading offers Lock, Sign Out, Restart, and Shut Down. Lock opens the configured session locker immediately; session-ending actions ask for confirmation. The NixOS service supplies `P3R_LOCK_COMMAND` for the standalone lock screen, and sign-out uses UWSM to end the Hyprland session.

The optional standalone lock screen lives in `lockscreen/` and is intentionally excluded from the widget launcher. The NixOS launcher `hypr-session-lock` supplies the MP4 wallpaper and avatar, with `hypr-session-lock --preview` providing a normal window that never locks or authenticates. Real locking uses Wayland's session-lock protocol and the existing `hyprlock` PAM service; only successful authentication unlocks. Password dots animate individually and retain no password characters. Qt Multimedia with VA-API plays the muted video loop, and Hyprlock remains a fallback if the Quickshell UI fails to launch.

The root `lock.qml` and `lock-preview.qml` entry points also embed the existing compact clock, Wi-Fi/battery indicator, and notch inside the lock surface. Calibration, media controls, charging/device notices, and volume/brightness OSD use the same widget components as the desktop. The lock-screen indicator is display-only, and notch calibration is disabled while locked.

The Hyprland screenshot helper saves captures in `Pictures/Screenshots`, copies them to the clipboard, and sends them to the preview through Quickshell IPC. Previews last 10 seconds; hovering or opening the menu keeps them visible. Save to… opens a file chooser, Share… opens an email draft with the screenshot attached, and Delete removes the saved capture. Sharing requires a configured email application. The preview's size, screen margins, and timeout are configurable in `screenshot/screenshot.qml`.

The calendar and clock use phase names returned by the [U.S. Naval Observatory API](https://aa.usno.navy.mil/data/api.html), mapping names such as `Full Moon` and `Waning Gibbous` directly to fixed glyph presets. The calendar requests each displayed date, including past and future dates, and the clock requests today. Results are cached across restarts; uncached dates need an internet connection. While a result is unavailable, an outline is shown. The API supports dates from 1700 through 2100. The unlit portion is black on the clock and the calendar's active day, and light gray on other calendar dates.

## Requirements

- An internet connection to fetch uncached moon-phase dates (no API key required).
- A Linux Wayland session with a compositor supporting the layer-shell protocol.
- **Quickshell**, including its Qt Quick, Wayland, I/O, and MPRIS modules and Qt Quick Effects support.
- **CAVA**, installed as `cava` on your `PATH`, for the bottom visualizer and Notch's audio bars.
- An audio backend supported by your CAVA installation. Both audio widgets default to **PipeWire**.
- An **MPRIS-compatible media player** for Notch's track information and controls.
- **UPower** and Quickshell's UPower module for laptop charging notices.
- **Git** to clone the repository, plus standard shell tools including `find` and `readlink`.

The clock and calendar look for Impact, Anton, Bebas Neue, Oswald, Archivo Black, and Arial Black. Install a preferred font for the intended appearance; the calendar falls back to sans-serif.

## Installation

Install Quickshell and CAVA using your distribution's package manager or their upstream installation instructions. No compilation or additional build step is needed for these QML files.

Clone the repository and run the installer as your normal desktop user, **without sudo**:

```sh
git clone https://github.com/Eduannnn/WIDGETS.git widgets
cd widgets
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
quickshell -p p3r-clock/clock.qml
quickshell -p calendar
quickshell -p cava/cava.qml
quickshell -p notch/notch.qml
```

Run only the command for the widget you want. The same preview commands also work from the repository directory.

The launcher supports excluding folders for a session, for example `P3R_WIDGETS_DISABLE=notch quickshell -p .`. Comma-separated names match immediate widget directories without regard to case. With no exclusions it starts every widget.

On Hyprland, the clock detects window overlap through native IPC and the notch reads monitor geometry through `hyprctl`. The notch supplies volume/mute and brightness OSDs using local SF Symbols; device notifications resume after the OSD dismisses. Plasma keeps its own system OSD.

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

Edit [`p3r-clock/clock.qml`](p3r-clock/clock.qml):

- `anchors` and `margins`: screen placement and distance from the edges.
- `horizontalScale` and `topPad`: proportions and space above the lettering.
- `fontChoices`: preferred display fonts, in priority order.
- `accentCyan`, `moonYellow`, and `ink`: accent, moon, and shadow colors.
- `animateWaves`: enable or freeze the background animation.
- `labelHeight`, `labelBaseline`, and `labelGap`: banner typography.

Hover over the widget to show the date instead of the digital clock.

When a visible window overlaps the full clock's area, the clock slides and fades into a compact row: `dd/MM`, `ddd`, `h:mm`, then the moon phase. Text is white and the moon stays yellow, with a shared size (`minimalRow.contentSize`). The row fits above the calibrated notch bottom. Moving the window away, minimizing it, or showing the desktop restores the full clock. Detection uses the full clock's resting bounds so resizing the clock cannot retrigger the transition.

On KDE, the installer builds a small Rust window-state monitor. For a source checkout, run `./p3r-clock/setup-window-state.sh` and restart the widgets. Building requires Cargo/Rust and a C compiler, or `nix-shell` on NixOS. The monitor observes KWin window bounds on the current desktop/activity without changing window positions or desktop settings. Other compositors retain the full clock because this monitor requires KWin.

### Calendar

Edit [`calendar/CalendarView.qml`](calendar/CalendarView.qml) for `moonColor` and `transitionMs` (the date scroll duration in milliseconds). Its layout scales from a 1440 × 900 reference stage to fit each screen.

Edit [`calendar/shell.qml`](calendar/shell.qml) to change the font preference list or date-preview settings. Keep `debugDateCycle: false` and `debugDayOffset: 0` for normal use. Setting `debugDateCycle` to `true` advances the preview date every ten seconds.

#### Outlook / Teams calendar events

The calendar can subscribe to your school's or your own Outlook calendar through its published ICS feed. Teams meetings appear in the corresponding Outlook calendar.

1. In Outlook on the web, open **Settings → Calendar → Shared calendars → Publish a calendar**. Select the calendar and the minimum detail level you need; availability-only is enough for date markers.
2. Publish it and copy the **ICS** subscription link. Keep this link private: anyone who has it can read the details you published.
3. From the repository or installed directory, run:

```sh
./calendar/setup-calendar.sh
```

The setup script compiles the Rust helper once and installs it to `${XDG_DATA_HOME:-~/.local/share}/p3r-widgets/bin/p3r-calendar-sync`. It uses your installed Cargo/Rust toolchain, or `nix-shell` on NixOS; other systems need Rust and a C compiler for the build. The running widgets only need the compiled executable. Paste the ICS link at the hidden prompt on first setup. The running widgets pick up the configuration within ten seconds.

Rerunning setup preserves an existing subscription and migrates older configurations automatically. Use `./calendar/setup-calendar.sh --configure` to replace the subscription link, or `--build-only` to install the helper without changing configuration. Build artifacts stay in the user's cache directory, outside the repository.

The URL is saved outside the repository in `${XDG_CONFIG_HOME:-~/.config}/p3r-widgets/calendar.json` with owner-only access. Calendar data is cached privately under `${XDG_CACHE_HOME:-~/.cache}/p3r-widgets/`. The widget checks for updates every five minutes and uses cached events if the feed is temporarily unavailable; Outlook controls how quickly published changes become available.

Underlines follow these rules:

- **Monday–Friday:** red when there are no calendar events; no underline when there is an event.
- **Saturday:** always blue, regardless of events.
- **Sunday:** always red, regardless of events.

Recurring meetings, moved occurrences, all-day events, and local time zones are supported. Cancelled occurrences are excluded. The clock's day triangle uses the same color as today's underline, falling back to black when there is no underline.

The clock also uses this feed for its school-day labels. A weekday with an event shows “Before School”, “Lunchtime”, and “After School” at the corresponding hours. Weekdays without events and weekends show “Early Morning”, “Midday”, and “Late Afternoon”. Until the calendar has synced, the clock uses these neutral labels. This treats any event in the subscribed school calendar as a school day.

### CAVA visualizer

Edit [`cava/cava.qml`](cava/cava.qml):

- `bars`, `barGap`, `maxHeight`, and `topRadius`: bar count and shape. Odd bar counts are rounded up to an even number.
- `sensitivity` and `curve`: response to audio levels.
- `barTop`, `barBottom`, and `barOpacity`: appearance.
- `silenceThreshold`, `silenceHoldMs`, and `fadeMs`: silence detection and fading.
- `inputMethod`: audio backend, such as `"pipewire"`, `"pulse"`, or `"alsa"`, depending on your CAVA build.

### Notch media widget

Edit [`notch/notch.qml`](notch/notch.qml):

- `screenName`: target output, initially `"eDP-1"`. The first available screen is used if no output matches.
- `notchWidth` and `notchHeight`: use saved calibration dimensions, falling back to 280 × 37.5 logical pixels before calibration. `wingWidth` controls the side extensions.
- `debugNotch`: show a calibration rectangle while adjusting placement.
- For the physical camera cutout, use the [temporary calibration overlay](notch/CALIBRATION.md). Saved logical coordinates drive the layout's position, dimensions, and no-content zone.
- Calibration setup opens automatically on launch until you save it. **Set up later** skips the current session. Reopen it anytime with `quickshell ipc -p . call notch calibrate`.
- `debugNotifications`: set to `true` to continuously replay the notification preview; `false` stops it.
- `uiScale`, `animMs`, and `collapseDelayMs`: size and animation timing.
- [Motion details](notch/MOTION.md): interruptible Qt springs and staged content fades, informed by Apple's public motion guidance and video demos. `animMs` controls spring response rather than a fixed settling duration.
- `accent`, `tintFromCover`, and `fontFamily`: appearance and artwork-based coloring.
- `barCount`: audio bar count. Change the audio backend inside `cavaConfig()` if needed; Notch has its own CAVA configuration.
- `bluetoothNoticeMs`: how long a device notice stays visible, initially 4 seconds.

Play media in an MPRIS-compatible application, then hover over Notch to expand it. Available controls and seeking depend on what the player supports.

Bluetooth controllers, headphones, earbuds, keyboards, mice, and other devices briefly show a white symbol on the left side of the collapsed notch. A reported Bluetooth battery level adds a ring and percentage on the right; the right wing retracts when battery information is unavailable or the device disconnects. Late battery reports update the notice while it is visible. USB controllers and audio devices are detected through `udevadm`, included with systemd. Notices work without media playback, queue when several devices change, and return to the previous media state. Existing Bluetooth connections are not announced at startup. Plain analog headphone jacks are not monitored.

On laptops, plugging in power briefly shows **Charging** on the left, with a green percentage and SF battery symbol on the right. UPower must report a present system battery; desktops and peripheral batteries do not trigger this notice. Already-connected power is silent on startup. Battery values update live, unplugging dismisses the notice, and media returns afterward. Charging and device notices share the same queue and display duration.

Preview simulated connection and disconnection notices on a running configuration:

```sh
quickshell ipc -p . call notch preview
```

Preview the charging layout on a laptop with `quickshell ipc -p . call notch previewCharging`.

The notice icons use locally extracted SF Symbols from `${XDG_DATA_HOME:-~/.local/share}/icons/SFSymbols/` when available, with system-icon fallbacks. See [the symbol exporter](notch/symbol-export/README.md) to extract your own downloaded font assets. Apple artwork is kept outside this repository.

Both audio widgets generate their CAVA configuration at runtime; there is no separate CAVA configuration file to install.

## Enable, disable, or add widgets

The root [`shell.qml`](shell.qml) loads every immediate subdirectory containing a `shell.qml` entry point. Helper components are not launched independently, and a widget loading error is logged without preventing the others from loading.

To disable a widget without deleting its source, rename its entry point in the installed directory and restart the service:

```sh
cd ~/.config/quickshell/p3r
mv cava/shell.qml cava/shell.qml.disabled
systemctl --user restart p3r-widgets.service
```

To enable it again:

```sh
cd ~/.config/quickshell/p3r
mv cava/shell.qml.disabled cava/shell.qml
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
