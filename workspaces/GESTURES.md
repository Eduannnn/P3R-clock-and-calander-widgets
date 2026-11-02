# Workspace gestures

The persistent Hyprland configuration lives in `/etc/nixos/home-modules/hyprland.nix`.
It includes `workspace-gestures.lua`; do not edit the generated `hyprland.lua`.

Three fingers sideways uses Hyprland's native workspace swipe. It tracks movement
directly, uses a 300-unit travel distance, a 45% completion threshold plus the
native speed override, and a critically damped spring for settling. Axis recognition
has Hyprland's built-in five-unit dead zone. Sign locking is disabled so movement
can reverse across the starting point. Swipes neither create workspaces nor cycle
through several workspaces in one gesture. Use **New** to create a desktop.

Three fingers vertically controls the notch drawer through native Lua gesture
callbacks and Socket2 events. There are no subprocesses on the update path.
The drawer follows displacement directly, projects its destination from signed
recent velocity, and preserves that velocity through spring settling. Cancellation
returns to its original target. A new gesture interrupts at its current position.
Only the drawer needs Quickshell physics; it never moves application windows.

Workspace and window events refresh previews instead of periodic polling.
The drawer width follows its preview row, with 14 logical pixels of padding on
each side and the existing six-pixel screen joins.

## Native limitations

Hyprland 0.57's horizontal swipe uses average absolute movement per input update,
not recent velocity in units per second or projected resting position. Its
workspace end handler does not inspect libinput's cancellation flag, and it
does not pass measured release velocity into the spring. Workspace boundaries
stop movement rather than rubber-band. These require compositor changes to
improve; configuration cannot promise full macOS behaviour. No plugins, drivers,
or extra recognizers are installed here.

## Verification

Run `node --test workspaces/tests/motion.test.cjs` from the widget repository.
Tests cover partial swipes, flicks, reversals, cancellation, frame-rate-independent
settling and continuity when interrupted. Socket2 integration is also checked
against the live drawer. These checks do not replace hands-on trackpad testing
of horizontal swipes, finger-count changes, or input-to-photon latency.

The laptop display runs at 60 Hz. Test slow, fast, reversed and interrupted swipes
with two or more desktops, including swiping outwards at both ends. To undo a
temporary live compositor preview before applying Nix changes, run `hyprctl reload`.
