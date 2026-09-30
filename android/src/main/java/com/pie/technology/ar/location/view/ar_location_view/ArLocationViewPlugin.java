package com.pie.technology.ar.location.view.ar_location_view;

import android.content.Context;
import android.hardware.GeomagneticField;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.display.DisplayManager;
import android.location.Location;
import android.location.LocationManager;
import android.os.SystemClock;
import android.util.Log;
import android.util.SizeF;
import android.view.Display;
import android.view.Surface;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;
import io.flutter.plugin.common.EventChannel.StreamHandler;
import io.flutter.plugin.common.MethodChannel;


/**
 * ArLocationViewPlugin
 */
public class ArLocationViewPlugin implements FlutterPlugin, StreamHandler {
    private static final String TAG = "ArLocationView";

    private static final float ALPHA = 0.45f;


    private static final int COMPASS_UPDATE_RATE_MS = 10;

    private SensorEventListener sensorEventListener;

    private Display display;
    private SensorManager sensorManager;

    @Nullable
    private Sensor compassSensor;
    @Nullable
    private Sensor gravitySensor;
    @Nullable
    private Sensor magneticFieldSensor;

    private float[] truncatedRotationVectorValue = new float[4];
    private float[] rotationMatrix = new float[9];
    private float[] rotationVectorValue;
    private float lastHeading;
    private int lastAccuracySensorStatus;

    private long compassUpdateNextTimestamp;
    private float[] gravityValues = new float[3];
    private float[] magneticValues = new float[3];

    private static final long DECLINATION_REFRESH_MS = 60_000;

    @Nullable
    private EventChannel channel;
    @Nullable
    private MethodChannel cameraChannel;
    private Context context;

    /**
     * Magnetic declination at the last known location, added to the magnetic
     * azimuth so the heading is relative to true north like on iOS.
     */
    private float declination;
    private long declinationNextUpdate;

    public ArLocationViewPlugin() {

    }

    private void init(Context context) {
        this.context = context;
        display = ((DisplayManager) context.getSystemService(Context.DISPLAY_SERVICE))
                .getDisplay(Display.DEFAULT_DISPLAY);
        sensorManager = (SensorManager) context.getSystemService(Context.SENSOR_SERVICE);
        compassSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR);
        if (compassSensor == null) {
            Log.d(TAG, "Rotation vector sensor not supported on device, "
                    + "falling back to accelerometer and magnetic field.");
        }

        gravitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        magneticFieldSensor = sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
    }

    // New Plugin APIs

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        init(binding.getApplicationContext());
        channel = new EventChannel(binding.getBinaryMessenger(), "pie/ar_view_location");
        channel.setStreamHandler(this);
        cameraChannel = new MethodChannel(binding.getBinaryMessenger(), "pie/ar_view_location/camera");
        cameraChannel.setMethodCallHandler((call, result) -> {
            if ("backCameraFieldOfView".equals(call.method)) {
                result.success(backCameraFieldOfView());
            } else {
                result.notImplemented();
            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        unregisterSensors();
        if (channel != null) {
            channel.setStreamHandler(null);
            channel = null;
        }
        if (cameraChannel != null) {
            cameraChannel.setMethodCallHandler(null);
            cameraChannel = null;
        }
    }

    /**
     * Field of view of the first back camera along the sensor's long side, in
     * degrees, from its physical sensor size and focal length; null if unknown.
     */
    @Nullable
    private Double backCameraFieldOfView() {
        CameraManager cameraManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
        if (cameraManager == null) {
            return null;
        }
        try {
            for (String id : cameraManager.getCameraIdList()) {
                CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(id);
                Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (facing == null || facing != CameraCharacteristics.LENS_FACING_BACK) {
                    continue;
                }
                SizeF sensorSize = characteristics.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE);
                float[] focalLengths = characteristics.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS);
                if (sensorSize == null || focalLengths == null || focalLengths.length == 0 || focalLengths[0] <= 0) {
                    return null;
                }
                double longSide = Math.max(sensorSize.getWidth(), sensorSize.getHeight());
                return Math.toDegrees(2 * Math.atan(longSide / (2 * focalLengths[0])));
            }
        } catch (CameraAccessException | IllegalArgumentException e) {
            Log.w(TAG, "Unable to read the back camera characteristics", e);
        }
        return null;
    }

    public void onListen(Object arguments, EventSink events) {
        // A new listen without a cancel (e.g. hot restart) must not leave the
        // previous listener registered and emitting to a dead sink.
        unregisterSensors();
        sensorEventListener = createSensorEventListener(events);
        lastAccuracySensorStatus = SensorManager.SENSOR_STATUS_NO_CONTACT;
        declinationNextUpdate = 0;

        if (isCompassSensorAvailable()) {
            sensorManager.registerListener(sensorEventListener, compassSensor, SensorManager.SENSOR_DELAY_GAME);
        } else {
            // Only needed for the fallback: keeping them on alongside the
            // rotation vector would just drain the battery.
            sensorManager.registerListener(sensorEventListener, gravitySensor, SensorManager.SENSOR_DELAY_GAME);
            sensorManager.registerListener(sensorEventListener, magneticFieldSensor, SensorManager.SENSOR_DELAY_GAME);
        }
    }

    public void onCancel(Object arguments) {
        unregisterSensors();
    }

    private void unregisterSensors() {
        if (sensorEventListener != null && sensorManager != null) {
            sensorManager.unregisterListener(sensorEventListener);
            sensorEventListener = null;
        }
    }

    /**
     * Refreshes {@link #declination} from the last known location, at most once
     * per {@link #DECLINATION_REFRESH_MS}. The declination barely changes over
     * a few kilometers, so a coarse/stale location is good enough.
     */
    private void updateDeclinationIfNeeded(long now) {
        if (now < declinationNextUpdate) {
            return;
        }
        declinationNextUpdate = now + DECLINATION_REFRESH_MS;
        Location location = lastKnownLocation();
        if (location == null) {
            // Retry sooner: the location usually becomes available shortly.
            declinationNextUpdate = now + 5_000;
            return;
        }
        declination = new GeomagneticField(
                (float) location.getLatitude(),
                (float) location.getLongitude(),
                (float) location.getAltitude(),
                System.currentTimeMillis()).getDeclination();
    }

    @Nullable
    private Location lastKnownLocation() {
        LocationManager locationManager = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        if (locationManager == null) {
            return null;
        }
        Location best = null;
        for (String provider : locationManager.getProviders(true)) {
            try {
                Location location = locationManager.getLastKnownLocation(provider);
                if (location != null && (best == null || location.getTime() > best.getTime())) {
                    best = location;
                }
            } catch (SecurityException ignored) {
                // Location permission not granted (yet): stay on magnetic north.
            }
        }
        return best;
    }

    private boolean isCompassSensorAvailable() {
        return compassSensor != null;
    }

    SensorEventListener createSensorEventListener(final EventSink events) {
        return new SensorEventListener() {
            @Override
            public void onSensorChanged(SensorEvent event) {
                if (lastAccuracySensorStatus == SensorManager.SENSOR_STATUS_UNRELIABLE) {
                    Log.d(TAG, "Compass sensor is unreliable, device calibration is needed.");
                    // Update the heading, even if the sensor is unreliable.
                    // This makes it possible to use a different indicator for the unreliable case,
                    // instead of just changing the RenderMode to NORMAL.
                }
                if (event.sensor.getType() == Sensor.TYPE_ROTATION_VECTOR) {
                    rotationVectorValue = getRotationVectorFromSensorEvent(event);
                    updateOrientation();
                } else if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER && !isCompassSensorAvailable()) {
                    gravityValues = lowPassFilter(getRotationVectorFromSensorEvent(event), gravityValues);
                    updateOrientation();
                } else if (event.sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD && !isCompassSensorAvailable()) {
                    magneticValues = lowPassFilter(getRotationVectorFromSensorEvent(event), magneticValues);
                    updateOrientation();
                }
            }

            @Override
            public void onAccuracyChanged(Sensor sensor, int accuracy) {
                // The accelerometer's accuracy says nothing about the heading.
                if (sensor.getType() == Sensor.TYPE_ROTATION_VECTOR
                        || sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD) {
                    lastAccuracySensorStatus = accuracy;
                }
            }

            @SuppressWarnings("SuspiciousNameCombination")
            private void updateOrientation() {
                // check when the last time the compass was updated, return if too soon.
                long currentTime = SystemClock.elapsedRealtime();
                if (currentTime < compassUpdateNextTimestamp) {
                    return;
                }

                if (rotationVectorValue != null) {
                    SensorManager.getRotationMatrixFromVector(rotationMatrix, rotationVectorValue);
                } else {
                    // Get rotation matrix given the gravity and geomagnetic matrices.
                    // It fails until both sensors produced a sample (or in free
                    // fall): emitting then would send an all-zero attitude.
                    if (!SensorManager.getRotationMatrix(rotationMatrix, null, gravityValues, magneticValues)) {
                        return;
                    }
                }

                int worldAxisForDeviceAxisX;
                int worldAxisForDeviceAxisY;

                // Assume the device screen was parallel to the ground,
                // and adjust the rotation matrix for the device orientation.
                switch (display.getRotation()) {
                    case Surface.ROTATION_90:
                        worldAxisForDeviceAxisX = SensorManager.AXIS_Y;
                        worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_X;
                        break;
                    case Surface.ROTATION_180:
                        worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_X;
                        worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_Y;
                        break;
                    case Surface.ROTATION_270:
                        worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_Y;
                        worldAxisForDeviceAxisY = SensorManager.AXIS_X;
                        break;
                    case Surface.ROTATION_0:
                    default:
                        worldAxisForDeviceAxisX = SensorManager.AXIS_X;
                        worldAxisForDeviceAxisY = SensorManager.AXIS_Y;
                        break;
                }

                float[] adjustedRotationMatrix = new float[9];
                SensorManager.remapCoordinateSystem(rotationMatrix, worldAxisForDeviceAxisX, worldAxisForDeviceAxisY,
                        adjustedRotationMatrix);
                // Screen frame -> magnetic world, before the pitch-dependent
                // remapping below (which is only meant for the legacy heading and
                // introduces a jump at ±45°).
                float[] screenToWorld = adjustedRotationMatrix.clone();

                // Transform rotation matrix into azimuth/pitch/roll
                float[] orientation = new float[3];
                SensorManager.getOrientation(adjustedRotationMatrix, orientation);

                if (orientation[1] < -Math.PI / 4) {
                    // The pitch is less than -45 degrees.
                    // Remap the axes as if the device screen was the instrument panel.
                    switch (display.getRotation()) {
                        case Surface.ROTATION_90:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_Z;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_X;
                            break;
                        case Surface.ROTATION_180:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_Z;
                            break;
                        case Surface.ROTATION_270:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_Z;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_X;
                            break;
                        case Surface.ROTATION_0:
                        default:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_Z;
                            break;
                    }
                } else if (orientation[1] > Math.PI / 4) {
                    // The pitch is larger than 45 degrees.
                    // Remap the axes as if the device screen was upside down and facing back.
                    switch (display.getRotation()) {
                        case Surface.ROTATION_90:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_Z;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_X;
                            break;
                        case Surface.ROTATION_180:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_Z;
                            break;
                        case Surface.ROTATION_270:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_Z;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_X;
                            break;
                        case Surface.ROTATION_0:
                        default:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_Z;
                            break;
                    }
                } else if (Math.abs(orientation[2]) > Math.PI / 2) {
                    // The roll is less than -90 degrees, or is larger than 90 degrees.
                    // Remap the axes as if the device screen was face down.
                    switch (display.getRotation()) {
                        case Surface.ROTATION_90:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_Y;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_X;
                            break;
                        case Surface.ROTATION_180:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_MINUS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_Y;
                            break;
                        case Surface.ROTATION_270:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_Y;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_X;
                            break;
                        case Surface.ROTATION_0:
                        default:
                            worldAxisForDeviceAxisX = SensorManager.AXIS_X;
                            worldAxisForDeviceAxisY = SensorManager.AXIS_MINUS_Y;
                            break;
                    }
                }

                SensorManager.remapCoordinateSystem(rotationMatrix, worldAxisForDeviceAxisX, worldAxisForDeviceAxisY,
                        adjustedRotationMatrix);

                // Transform rotation matrix into azimuth/pitch/roll
                SensorManager.getOrientation(adjustedRotationMatrix, orientation);

                updateDeclinationIfNeeded(currentTime);
                double heading = (Math.toDegrees(orientation[0]) + declination + 360.0) % 360.0;

                // Same layout and units as iOS: [heading, headingForCameraMode,
                // accuracy in degrees]. The axes are already remapped for the
                // back camera when the device is upright, so both headings match.
                double[] worldToScreen = worldToScreen(screenToWorld, declination);
                double[] v = new double[12];
                v[0] = heading;
                v[1] = heading;
                v[2] = getAccuracy();
                System.arraycopy(worldToScreen, 0, v, 3, 9);
                notifyCompassChangeListeners(v);

                // Update the compassUpdateNextTimestamp
                compassUpdateNextTimestamp = currentTime + COMPASS_UPDATE_RATE_MS;
            }

            /**
             * Converts a screen -> magnetic ENU matrix into the row-major true
             * ENU -> screen matrix expected by the Dart side
             * ({@code ArSensor.rotationMatrix}).
             */
            private double[] worldToScreen(float[] screenToMagnetic, float declinationDegrees) {
                // Magnetic -> true world is a rotation around Up by the
                // declination (east positive).
                double d = Math.toRadians(declinationDegrees);
                double cos = Math.cos(d);
                double sin = Math.sin(d);
                double[] screenToTrue = new double[9];
                for (int col = 0; col < 3; col++) {
                    double east = screenToMagnetic[col];
                    double north = screenToMagnetic[3 + col];
                    screenToTrue[col] = cos * east + sin * north;
                    screenToTrue[3 + col] = -sin * east + cos * north;
                    screenToTrue[6 + col] = screenToMagnetic[6 + col];
                }
                // Rotation matrices are orthonormal: the inverse is the transpose.
                double[] result = new double[9];
                for (int row = 0; row < 3; row++) {
                    for (int col = 0; col < 3; col++) {
                        result[row * 3 + col] = screenToTrue[col * 3 + row];
                    }
                }
                return result;
            }

            private void notifyCompassChangeListeners(double[] heading) {
                events.success(heading);
                lastHeading = (float) heading[0];
            }

            /**
             * Android only reports a coarse accuracy status: map it to an
             * approximate error in degrees (-1 = unknown/unreliable), matching
             * the unit of iOS {@code CLHeading.headingAccuracy}.
             */
            private double getAccuracy() {
                switch (lastAccuracySensorStatus) {
                    case SensorManager.SENSOR_STATUS_ACCURACY_HIGH:
                        return 15;
                    case SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM:
                        return 30;
                    case SensorManager.SENSOR_STATUS_ACCURACY_LOW:
                        return 45;
                    default:
                        return -1;
                }
            }

            /**
             * Helper function, that filters newValues, considering previous values
             *
             * @param newValues      array of float, that contains new data
             * @param smoothedValues array of float, that contains previous state
             * @return float filtered array of float
             */
            private float[] lowPassFilter(float[] newValues, float[] smoothedValues) {
                if (smoothedValues == null) {
                    return newValues;
                }
                for (int i = 0; i < newValues.length; i++) {
                    smoothedValues[i] = smoothedValues[i] + ALPHA * (newValues[i] - smoothedValues[i]);
                }
                return smoothedValues;
            }

            /**
             * Pulls out the rotation vector from a SensorEvent, with a maximum length
             * vector of four elements to avoid potential compatibility issues.
             *
             * @param event the sensor event
             * @return the events rotation vector, potentially truncated
             */
            @NonNull
            private float[] getRotationVectorFromSensorEvent(@NonNull SensorEvent event) {
                if (event.values.length > 4) {
                    // On some Samsung devices SensorManager.getRotationMatrixFromVector
                    // appears to throw an exception if rotation vector has length > 4.
                    // For the purposes of this class the first 4 values of the
                    // rotation vector are sufficient (see crbug.com/335298 for details).
                    // Only affects Android 4.3
                    System.arraycopy(event.values, 0, truncatedRotationVectorValue, 0, 4);
                    return truncatedRotationVectorValue;
                } else {
                    return event.values;
                }
            }
        };
    }
}
