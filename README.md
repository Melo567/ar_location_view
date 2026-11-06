# ar_location_view

Location-based augmented reality for Flutter: labels of geolocated points of
interest (POIs) are drawn over the camera preview, in the direction of each
POI. Inspired by [HDAugmentedReality](https://github.com/DanijelHuis/HDAugmentedReality).

Designed for areas with a large concentration of static POIs, where the
primary goal is that every POI stays visible.

![ArLocationView](./demo.gif)

## Features

* 3D projection from the full device attitude (heading, pitch and roll),
  matched to the real camera field of view.
* Automatic vertical stacking of overlapping labels, stable across frames;
  POIs that do not fit are grouped under a "+N" badge.
* Smoothed compass and GPS (adaptive attitude filter, Kalman location
  filter), both configurable.
* Optional altitude-aware placement, distance-based scaling and radar.
* Fully customizable annotation views, loading and error states.
* Supports all orientations. Sensors and camera are paused in background.

## Installation

```sh
flutter pub add ar_location_view
```

### iOS

Add the usage descriptions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>The camera shows the points of interest around you.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is used to place the points of interest around you.</string>
```

Permissions are requested with
[permission_handler](https://pub.dev/packages/permission_handler), which
needs the camera and location permissions enabled in `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_LOCATION=1',
      ]
    end
  end
end
```

### Android

The plugin declares the camera and location permissions; nothing to add to
your manifest. The compass and gyroscope are declared as optional features
(the plugin falls back when they are missing), so they do not restrict the
devices your app is available to on the Play Store.

With `permission_handler` 13 (resolved by default), compile your app
against Android SDK 37 in `android/app/build.gradle`:

```groovy
android {
    compileSdk 37
}
```

To stay on a lower `compileSdk`, pin `permission_handler: ^12.0.1` in your
app's `pubspec.yaml`.

## Usage

Extend `ArAnnotation` with your own data:

```dart
class Poi extends ArAnnotation {
  Poi({required super.uid, required super.position, required this.name});

  final String name;
}
```

Then show them with `ArLocationWidget`, which combines the camera preview
and the AR overlay:

```dart
ArLocationWidget(
  annotations: pois,
  annotationWidth: 180,
  annotationHeight: 60,
  annotationViewBuilder: (context, annotation) {
    final poi = annotation as Poi;
    return Card(
      child: ListTile(
        title: Text(poi.name),
        subtitle: Text('${poi.distanceFromUser.round()} m'),
      ),
    );
  },
  // Called with the first location, then every `minDistanceReload` meters.
  onLocationChange: (position) => loadPoisAround(position),
)
```

See the [example](example/lib/main.dart) for a complete app.

The annotation builder is not called on every frame: its result is reused
until the annotation's distance or its grouped annotations change, or until
the widget is rebuilt by its parent.

### Customization

| Parameter | Description |
|---|---|
| `maxVisibleDistance` | POIs farther than this (meters) are hidden. Also the radar range. |
| `scaleWithDistance`, `minScale` | Shrink labels linearly with distance, down to `minScale`. |
| `paddingOverlap`, `yOffsetOverlap` | Vertical spacing of stacked labels. |
| `maxRows` | Maximum number of stacked rows; extra POIs are grouped. |
| `groupBadgeBuilder` | Badge shown on a label with grouped POIs (default "+N"). |
| `useAltitude` | Place POIs above/below the horizon from their altitude. Requires POI altitudes in the same reference as the GPS. |
| `hideWithinLocationAccuracy` | Hide POIs closer than the GPS accuracy. |
| `cameraFieldOfView` | Override the field of view read from the device. |
| `showRadar`, `radarPosition`, `radarWidth`, `markerColor`, `backgroundRadar` | Radar. |
| `accessory` | Widget drawn above the overlay once the camera is ready. |
| `isLoading`, `loadingWidget` | Loading overlay, e.g. while fetching POIs. |
| `cameraErrorBuilder` | Shown when the camera permission is denied or the camera is unavailable. |
| `sensorErrorBuilder` | Shown when the location permission is denied or location services are off. |

When a permission is denied and the user grants it from the system settings,
the view starts by itself when the app returns to the foreground.

### Sensors

`ArView` (the overlay without the camera, used by `ArLocationWidget`) reads
the device through an `ArSensorSource`. By default it creates an
`ArSensorManager`, which you can also create yourself to tune it or share it
between several views:

```dart
final sensors = ArSensorManager(
  // Smoothing of the compass, see AttitudeFilter / HeadingFilter.
  attitudeFilter: AttitudeFilter(timeConstant: 0.4),
  // Kalman filter of the GPS fixes; `smoothLocation: false` disables it.
  locationFilter: LocationFilter(processNoise: 1.5),
  locationSettings: const LocationSettings(distanceFilter: 2),
);

ArLocationWidget(sensorSource: sensors, /* ... */);
```

A source you provide is yours: `ArView` neither pauses nor disposes it. Call
`sensors.pause()` / `resume()` with the app lifecycle and `dispose()` when
done.

To test without hardware, implement `ArSensorSource` with a fake that emits
`ArSensor` samples, or pass an `ArSensorBackend` with your own streams to
`ArSensorManager`.

### Layout engine

`AnnotationLayoutEngine` is the pure Dart geometry behind `ArView`: it turns
a sensor sample and a list of annotations into positioned, de-collided
labels. Use it directly to draw the labels your own way.

## Created by [@Melo567](https://github.com/Melo567)

Liked some of my work? Buy me a coffee. Thanks for your support :heart:

<a href="https://buymeacoffee.com/Melo567" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-blue.png" alt="Buy Me A Coffee" height=64></a>

## License

MIT, see [LICENSE](LICENSE).
