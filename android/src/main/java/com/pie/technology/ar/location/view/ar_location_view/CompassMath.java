package com.pie.technology.ar.location.view.ar_location_view;

import android.content.res.Configuration;
import android.hardware.SensorManager;
import android.view.Surface;

/**
 * Pure computations behind the compass events, kept free of Android state so
 * they can be unit tested on the JVM.
 */
final class CompassMath {
    // Indexes of Flutter's DeviceOrientation, sent with each compass event.
    static final int ORIENTATION_UNKNOWN = -1;
    static final int ORIENTATION_PORTRAIT_UP = 0;
    static final int ORIENTATION_LANDSCAPE_LEFT = 1;
    static final int ORIENTATION_PORTRAIT_DOWN = 2;
    static final int ORIENTATION_LANDSCAPE_RIGHT = 3;

    /** Number of values of a compass event, see {@link #payload}. */
    static final int PAYLOAD_LENGTH = 13;

    private CompassMath() {
    }

    /**
     * UI orientation as the index of Flutter's {@code DeviceOrientation}, or
     * {@link #ORIENTATION_UNKNOWN}. Crossing the configuration with the
     * display rotation also handles devices whose natural orientation is
     * landscape, as the native_device_orientation plugin did.
     *
     * @param configurationOrientation {@link Configuration#orientation}
     * @param rotation                 {@link android.view.Display#getRotation()}
     */
    static int orientation(int configurationOrientation, int rotation) {
        boolean notFlipped = rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_90;
        switch (configurationOrientation) {
            case Configuration.ORIENTATION_PORTRAIT:
                return notFlipped ? ORIENTATION_PORTRAIT_UP : ORIENTATION_PORTRAIT_DOWN;
            case Configuration.ORIENTATION_LANDSCAPE:
                return notFlipped ? ORIENTATION_LANDSCAPE_LEFT : ORIENTATION_LANDSCAPE_RIGHT;
            default:
                return ORIENTATION_UNKNOWN;
        }
    }

    /**
     * Android only reports a coarse accuracy status: map it to an
     * approximate error in degrees (-1 = unknown/unreliable), matching
     * the unit of iOS {@code CLHeading.headingAccuracy}.
     */
    static double accuracyDegrees(int sensorStatus) {
        switch (sensorStatus) {
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
     * Converts a row-major screen -> magnetic ENU matrix into the row-major
     * true ENU -> screen matrix expected by the Dart side
     * ({@code ArSensor.rotationMatrix}).
     */
    static double[] worldToScreen(float[] screenToMagnetic, float declinationDegrees) {
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

    /**
     * Same layout and units as iOS: [heading, headingForCameraMode, accuracy
     * in degrees, m0...m8, orientation]. The axes are already remapped for
     * the back camera when the device is upright, so both headings match.
     */
    static double[] payload(double heading, double accuracy, double[] worldToScreen, int orientation) {
        double[] v = new double[PAYLOAD_LENGTH];
        v[0] = heading;
        v[1] = heading;
        v[2] = accuracy;
        System.arraycopy(worldToScreen, 0, v, 3, 9);
        v[12] = orientation;
        return v;
    }
}
