# Notch motion

Motion is adapted from Apple's public guidance and demos, with Qt-specific
parameters. It does not reproduce undocumented Dynamic Island spring constants.

## References

- [Animate with springs, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10158/):
  preserve velocity when retargeting; let motion settle gradually; use modest
  bounce rather than making every transition elastic.
- [Apple's Dynamic Island demo](https://www.apple.com/newsroom/videos/iphone-14-pro-dynamic-island-face-id/large_2x.mp4):
  frame inspection shows the black shape opening ahead of the content, with
  content fading away as the shape contracts.
- [Qt SpringAnimation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html):
  the native spring implementation used by `MotionSpring.qml`.

## Implementation

Width and the asymmetric right edge use matching, interruptible springs.
Height, corner radius, and screen joins use a smoother spring. Height is also
bounded by the calibrated cutout height, so contracting cannot undershoot it.
`animMs` controls response tempo; settling can continue briefly afterward.
`entranceMs` controls the gentler side-content reveal.

`MotionContent.qml` clears outgoing content in 75ms. Incoming content waits
35ms for the shape, then fades in over 145ms. Larger media views travel only
5–6 logical pixels into their resting positions. Side indicators stay on their
calibrated baseline. Icons crossfade when the queued device changes; battery
updates do not replay that transition. Playback button feedback uses a small
spring response.

No display settings, calibration, resting dimensions, or seeking behavior are
changed by these animations. The foreground cutout mask remains enabled during
every transition. Native animations stop when settled; no animation polling loop
or full-screen blur is added.
