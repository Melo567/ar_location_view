## 3.0.0

**Breaking changes**

* `ArAnnotation.arPosition.dx` is now the label's left edge in screen coordinates (it used to be an offset in pixels relative to the heading, which rendered annotations shifted by half a screen).
* Remove the public `ArSensorManager.pitchHistory` field.
* `ArView` no longer disposes an `ArSensorSource` passed through `sensorSource`: its owner is now responsible for calling `dispose()`.
* `ArSensorManager.arSensor` is now a broadcast stream and reports failures as `ArSensorException` stream errors.
* On Android, the heading is now relative to **true north** (magnetic declination applied), like on iOS. Where the declination is large, POIs move by that many degrees.
* `ArSensor.compassAccuracy` is now an error in degrees on both platforms, or `-1` when unknown (Android used to report the raw sensor status, 0–3).
* `ArSensorManager` no longer uses the user accelerometer, and the pitch smoothing is now time-based (~0.5 s time constant instead of ~2 s).
* `ArAnnotation.arPosition` is now the label's **top-left corner** in screen coordinates, the label being centered on the POI (`dy` used to be a pitch offset added to half the screen height, placing the label's top edge on the horizon).
* POIs are now positioned with a 3D projection: `ArSensor.heading`/`pitch` are derived from the device attitude on both platforms and the compass event channel payload now carries a rotation matrix.

**Positioning**

* Project POIs with the full device attitude (new `ArSensor.rotationMatrix`, provided natively on Android and iOS) and a pinhole camera model (`ArProjection`), instead of a linear degrees-to-pixels mapping on heading and pitch. This accounts for the device roll, removes the heading jump when tilting the device past ±45° on Android, and hides POIs behind the camera.
* Use the real camera field of view, read from the device (`ArCameraInfo.backCameraFieldOfView()`), instead of a hard-coded 58°. It can be overridden with `cameraFieldOfView` on `ArView`/`ArLocationWidget`. The preview aspect ratio is taken into account to match the cropped preview.
* Use the UI orientation as the single screen reference on both platforms (the pitch and field of view used the physical device orientation while the Android heading used the display rotation).
* Center labels vertically on the POI, and only keep POIs whose label intersects the screen vertically too.
* Add opt-in `useAltitude` to place POIs above/below the horizon from their altitude difference with the user.
* Fix `ArAnnotation.isVisible` staying `true` for annotations moved out of range.
* Custom `ArSensorSource`s without a rotation matrix keep working: the attitude is rebuilt from `heading` and `pitch` (no roll).

**Stability**

* Smooth the device attitude with an adaptive, time-based filter (`AttitudeFilter`): compass jitter is damped while the device is still, fast rotations are followed without lag. Without a rotation matrix, the heading is smoothed the same way, across north (`HeadingFilter`).
* Smooth GPS fixes with a Kalman filter weighted by their accuracy (`LocationFilter`), so nearby POIs no longer swing with GPS noise. `onLocationChange` and the reported accuracy use the filtered position.
* Both filters are configurable, or can be disabled, through the new `ArSensorManager` constructor parameters.
* Keep labels on the same overlap row across frames (`previousRows` / `AnnotationLayoutResult.rows`, with `AnnotationLayoutConfig.rowHysteresis` of clearance required to move back down), and animate row changes (`rowAnimationDuration` on `ArView`).
* Add opt-in `hideWithinLocationAccuracy` to hide POIs closer than the location accuracy.
* Labels scaled with `scaleWithDistance` now shrink linearly from 1 down to a configurable `minScale` (default 0.5) at `maxVisibleDistance`, instead of the hard-coded `1 - d / (maxVisibleDistance + 280)`, which went down to ~0.16 and made far labels unreadable. Use `minScale: 0.16` to get the previous look back. The scale is computed by the layout and exposed as `ArAnnotation.arScale`.
* Overlaps are detected on each label's displayed (scaled) width, with a configurable `horizontalSpacing` between labels: small far labels are no longer pushed onto extra rows by their unscaled size.
* Cache each annotation's bearing and distance (`AnnotationGeoCache`) instead of recomputing them for every annotation on every frame: they are only recomputed when the user or the annotation moves.
* `ArView` now projects onto its own size (`LayoutBuilder`) instead of the screen size, so annotations stay aligned with the camera preview when the view does not fill the screen.
* Stop stacking overlapping labels above the top of the screen, and add an optional `maxRows` limit. Annotations that do not fit are grouped into the overlapping visible label whose center is closest (`AnnotationLayoutResult.groups`), which shows a "+N" badge (customizable with `groupBadgeBuilder` on `ArView`/`ArLocationWidget`). The closest POIs stay visible, the farthest ones are grouped.

**Bug fixes**

* Fix pitch being underestimated by ~40% (and close to 0 at startup): the exponential filter did not have unit gain. It is replaced by a recursive `LowPassFilter`.
* Fix annotations being drawn half a screen to the left: a POI straight ahead is now centered, and only POIs inside the displayed horizontal field of view are kept.
* Fix sharing one `ArSensorSource` between several views (`Stream has already been listened to`, and the first view closing the source used by the others). `ArSensorManager.init()` is now idempotent.
* Fix `ArSensorManager` starting the sensors, and adding events to a closed stream, when disposed while the location permission prompt was open.
* Fix `ArCamera` calling `setState()` after `dispose()` when the widget was removed during the permission request or camera initialization.
* Fix the camera preview being frozen or broken after the app returns from background: the camera is now released and restarted with the app lifecycle.
* Fix `ArView` showing a spinner forever when the location permission is denied or location services are disabled.
* Fix the camera preview scale, which depended on the screen pixel density: the preview now covers the view (like `BoxFit.cover`).
* Use the back camera explicitly (instead of the first camera listed) and `ResolutionPreset.high` instead of `max`.
* Fix radar markers beyond `maxVisibleDistance` being drawn outside the radar disc.
* Fix a jerky pitch: the accelerometer now runs at 50 Hz instead of 5 Hz, and only accelerometer samples update the pitch filter (it used to be driven by compass and GPS events with stale values).
* Fix the heading freezing while the compass was uncalibrated (events without accuracy were dropped).
* Android: fix heading range (now `[0, 360)` instead of `[-180, 180]`), `headingForCameraMode` always being 0, heading accuracy being overwritten by the accelerometer's, accelerometer/magnetometer staying on alongside the rotation vector sensor, a listener leaking when the stream was listened to again, and the stream handler not being released on engine detach.
* iOS: fall back to the magnetic heading when the true heading is unavailable, set `headingOrientation` from the device orientation (heading was off by ±90° in landscape), and only run CoreMotion while the compass stream is listened to.

**New**

* Add `ArSensorException` / `ArSensorErrorType`, and a `sensorErrorBuilder` on `ArView` and `ArLocationWidget` to customize the error shown when location is unavailable.

## 2.1.0

* Remove unused `ACCESS_BACKGROUND_LOCATION` permission from the Android manifest.
* Upgrade Android toolchain (AGP, Kotlin, Gradle, compileSdk, Java 17) for compatibility with recent Flutter/Android Studio versions.
* Update example iOS project (deployment target, Podfile) for compatibility with current Xcode/CocoaPods tooling.
* Add `ArSensorSource` interface so sensors can be injected into `ArView`/`ArLocationWidget` instead of relying on a hardcoded singleton.
* Extract annotation positioning/collision logic into a standalone `AnnotationLayoutEngine`, unit tested independently of Flutter widgets.
* Fix `ArView` performing side effects (position updates, `onLocationChange`) during `build()`.
* Fix potential incorrect widget reconciliation by keying annotation views with `ValueKey(annotation.uid)`.
* Improve performance of annotation overlap resolution (O(n²) to O(n log n) in the common case).

## 20.16
* Upgrade sensor

## 2.0.15
* Update gradle

## 2.0.12

* Solve scale camera

## 2.0.11

* Update dependencies
* add permission HIGH_SAMPLING_RATE_SENSORS for android 12

## 2.0.5

* Solve ArPluginsNotFound for Android

## 2.0.0

* Add radar.

## 1.0.0

* Add documentation.

## 0.0.5

* Resolve bug.

## 0.0.4

* Filter pitch.

## 0.0.3

* Update example with fake annotation.
* Resolve offset for overlap annotation sort annotation for distance user

## 0.0.2

*  Update example.

## 0.0.1

*  Describe initial release.
