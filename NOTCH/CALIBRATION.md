# Camera cutout calibration

Open the temporary overlay on the running widget configuration:

```sh
quickshell ipc -p . call notch calibrate
```

The top band is white so the physical black cutout is easy to see. Adjust **width**,
**height**, **horizontal offset**, and **corner radius** in the separate control
window. All controls use logical pixels; physical estimates are also displayed.
Start with the approximate width and adjust until colored fringes match the
camera's edges. A screenshot cannot establish the exact physical camera bounds.

**Save & close** writes `${XDG_CONFIG_HOME:-~/.config}/p3r-widgets/notch.json` and
disables the overlay. **Close without saving**, Escape, or the window close button
leaves the existing calibration intact. The checkbox hides just the rectangle.
It can also be disabled remotely:

```sh
quickshell ipc -p . call notch hideCalibration
```

The file contains output-local logical `x`, `y`, `width`, `height`, and
`cornerRadius`, the output name, logical screen size, physical mode, and scale.
The rectangle is explicitly user calibrated; the initial guess is never saved
automatically. Recalibrate after a mode, scale, orientation, or output change.

The widget treats the whole rectangle plus two logical pixels of padding as a
no-content zone. Compact and expanded content moves below it; collapsed icons
and audio bars stay in the side wings. Side wings grow only if needed to fit the
calibrated cutout. A GPU mask excludes foreground pixels during animations too.
The black widget background can span the cutout. No KDE or display settings are
changed, and the overlay starts disabled.

All collapsed presentations, including device notices with battery information,
use the calibrated height exactly. Safety padding applies to foreground
exclusion only; it must not increase the black background's resting height.

## Layout around the notch

The reference images guide placement; their timer, call, and casting
features are not implemented. The widget remains attached to the top edge.

- **Collapsed music:** cover art sits left of the calibrated cutout, with the
  waveform on the right. The calibrated width, height, and horizontal center
  replace the nominal camera dimensions across all presentation states.
- **Device notices:** a white symbol occupies only the left wing.
  A reported battery level opens the right wing with a ring and percentage.
  Without a battery report, that wing retracts behind the physical cutout's
  rounded corner, with no extra background height below the camera.
- **Track-change peek:** artwork, scrolling metadata, and waveform share one
  row below the cutout.
- **Expanded music:** artwork stays on the left and the waveform on the right;
  metadata, seeking, and playback controls occupy the space below the cutout.

The larger views share a 14-logical-pixel side inset and center their metadata
and waveform on the artwork. Artist text is secondary; when absent, the title
centers vertically by itself. Long metadata scrolls inside its own column.
Elapsed and remaining time share a baseline. The progress track remains visible
when duration is unavailable, with seeking disabled. Playback controls share a center line,
with their pointer hit areas contained inside the panel.

The collapsed cover and waveform use the cutout's measured left and right
edges directly. Notification symbols allow for their optical overhang, while
battery rings sit fully outside the protected rectangle. Do not use the
foreground safety padding to enlarge the collapsed black background.

Apple calls the paired side regions “compact”; this code calls that state
`collapsed` and uses `compact` for the larger track-change peek. Keep those
existing state names when editing bindings. Preserve the calibrated exclusion
mask throughout transitions rather than moving content through the cutout.

Placement follows the leading/trailing regions and consistent relative
positions described in Apple's [Live Activities design guidance](https://developer.apple.com/design/human-interface-guidelines/live-activities)
and [ActivityKit presentation documentation](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).
Phone-specific pill dimensions do not define the MacBook's cutout geometry.

## Display-stack investigation on this machine

- KScreen reports `eDP-1`, 2560×1664 at **1.5×**, with rounded 1707×1110 desktop
  geometry. Its output JSON does not supply a cutout rectangle.
- Qt/Quickshell reports 1707×1109 logical screen geometry and **2× backing DPR**.
  A full-width top-edge probe reports zero `SafeArea` margins. Buffer DPR is not
  the compositor scale; using it to divide physical measurements would be wrong.
  [Qt SafeArea documentation](https://doc.qt.io/qt-6/qml-qtquick-safearea.html)
  describes margins, rather than a cutout polygon or its exact width.
- `drm_info /dev/dri/card2` exposes the eDP mode and standard EDID, DPMS, link,
  tile, and CRTC properties. No cutout bounds are exposed by this connector.
- The device-tree node
  `/sys/firmware/devicetree/base/soc/dcp@231c00000/apple,notch-height` contains
  **64 physical pixels**, equivalent to 42.6667 logical pixels at 150%. The
  [Asahi DCP driver](https://github.com/AsahiLinux/linux/blob/asahi/drivers/gpu/drm/apple/dcp.c)
  reads this height for notch cropping. No width, horizontal bounds, or corner
  radius were found. The active `appledrm.show_notch` parameter is already on.

Manual calibration is therefore necessary for the complete rectangle. The
driver height is an initial hint, and the screenshot's approximate 310px width
is seeded as a physical-pixel estimate, not a verified measurement.
