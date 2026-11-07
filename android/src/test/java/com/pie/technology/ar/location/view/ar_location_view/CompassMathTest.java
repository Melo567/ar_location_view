package com.pie.technology.ar.location.view.ar_location_view;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;

import android.content.res.Configuration;
import android.hardware.SensorManager;
import android.view.Surface;

import org.junit.Test;

public class CompassMathTest {
    private static final double EPSILON = 1e-9;

    private static final float[] IDENTITY = {
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
    };

    @Test
    public void orientationOfAPhone() {
        assertEquals(CompassMath.ORIENTATION_PORTRAIT_UP,
                CompassMath.orientation(Configuration.ORIENTATION_PORTRAIT, Surface.ROTATION_0));
        assertEquals(CompassMath.ORIENTATION_LANDSCAPE_LEFT,
                CompassMath.orientation(Configuration.ORIENTATION_LANDSCAPE, Surface.ROTATION_90));
        assertEquals(CompassMath.ORIENTATION_PORTRAIT_DOWN,
                CompassMath.orientation(Configuration.ORIENTATION_PORTRAIT, Surface.ROTATION_180));
        assertEquals(CompassMath.ORIENTATION_LANDSCAPE_RIGHT,
                CompassMath.orientation(Configuration.ORIENTATION_LANDSCAPE, Surface.ROTATION_270));
    }

    @Test
    public void orientationOfADeviceNaturallyInLandscape() {
        // A tablet held as designed is in landscape at rotation 0.
        assertEquals(CompassMath.ORIENTATION_LANDSCAPE_LEFT,
                CompassMath.orientation(Configuration.ORIENTATION_LANDSCAPE, Surface.ROTATION_0));
        assertEquals(CompassMath.ORIENTATION_PORTRAIT_UP,
                CompassMath.orientation(Configuration.ORIENTATION_PORTRAIT, Surface.ROTATION_90));
        assertEquals(CompassMath.ORIENTATION_LANDSCAPE_RIGHT,
                CompassMath.orientation(Configuration.ORIENTATION_LANDSCAPE, Surface.ROTATION_180));
        assertEquals(CompassMath.ORIENTATION_PORTRAIT_DOWN,
                CompassMath.orientation(Configuration.ORIENTATION_PORTRAIT, Surface.ROTATION_270));
    }

    @Test
    public void orientationIsUnknownWithoutConfiguration() {
        assertEquals(CompassMath.ORIENTATION_UNKNOWN,
                CompassMath.orientation(Configuration.ORIENTATION_UNDEFINED, Surface.ROTATION_0));
    }

    @Test
    public void orientationCodesAreTheIndexesOfFlutterDeviceOrientation() {
        // DeviceOrientation.values: portraitUp, landscapeLeft, portraitDown,
        // landscapeRight.
        assertEquals(0, CompassMath.ORIENTATION_PORTRAIT_UP);
        assertEquals(1, CompassMath.ORIENTATION_LANDSCAPE_LEFT);
        assertEquals(2, CompassMath.ORIENTATION_PORTRAIT_DOWN);
        assertEquals(3, CompassMath.ORIENTATION_LANDSCAPE_RIGHT);
    }

    @Test
    public void accuracyInDegrees() {
        assertEquals(15, CompassMath.accuracyDegrees(SensorManager.SENSOR_STATUS_ACCURACY_HIGH), 0);
        assertEquals(30, CompassMath.accuracyDegrees(SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM), 0);
        assertEquals(45, CompassMath.accuracyDegrees(SensorManager.SENSOR_STATUS_ACCURACY_LOW), 0);
        assertEquals(-1, CompassMath.accuracyDegrees(SensorManager.SENSOR_STATUS_UNRELIABLE), 0);
        assertEquals(-1, CompassMath.accuracyDegrees(SensorManager.SENSOR_STATUS_NO_CONTACT), 0);
    }

    @Test
    public void worldToScreenIsTheInverseWithoutDeclination() {
        // Screen -> magnetic: a rotation of 30° around Up.
        double a = Math.toRadians(30);
        float c = (float) Math.cos(a);
        float s = (float) Math.sin(a);
        float[] screenToMagnetic = {
                c, -s, 0,
                s, c, 0,
                0, 0, 1,
        };

        double[] m = CompassMath.worldToScreen(screenToMagnetic, 0);

        assertArrayEquals(new double[]{
                c, s, 0,
                -s, c, 0,
                0, 0, 1,
        }, m, 1e-6);
    }

    @Test
    public void declinationMovesTrueNorthAwayFromMagneticNorth() {
        // Screen aligned with the magnetic frame (x = magnetic east, y =
        // magnetic north). With a 90° east declination, magnetic north is
        // true east, so true east must map to the screen's y axis.
        double[] m = CompassMath.worldToScreen(IDENTITY, 90);
        double[] trueEast = multiply(m, new double[]{1, 0, 0});
        double[] trueNorth = multiply(m, new double[]{0, 1, 0});

        assertArrayEquals(new double[]{0, 1, 0}, trueEast, EPSILON);
        assertArrayEquals(new double[]{-1, 0, 0}, trueNorth, EPSILON);
    }

    @Test
    public void worldToScreenStaysOrthonormal() {
        float[] screenToMagnetic = rotation(0.3, -0.7, 1.2);

        double[] m = CompassMath.worldToScreen(screenToMagnetic, 12.5f);

        double[] product = multiply(m, transpose(m));
        assertArrayEquals(new double[]{1, 0, 0, 0, 1, 0, 0, 0, 1}, product, 1e-6);
    }

    @Test
    public void payloadLayout() {
        double[] matrix = {1, 2, 3, 4, 5, 6, 7, 8, 9};

        double[] payload = CompassMath.payload(
                42, 15, matrix, CompassMath.ORIENTATION_LANDSCAPE_RIGHT);

        assertEquals(CompassMath.PAYLOAD_LENGTH, payload.length);
        assertArrayEquals(new double[]{42, 42, 15, 1, 2, 3, 4, 5, 6, 7, 8, 9, 3},
                payload, EPSILON);
    }

    /** Row-major rotation from yaw, pitch and roll, in radians. */
    private static float[] rotation(double yaw, double pitch, double roll) {
        double[] z = {
                Math.cos(yaw), -Math.sin(yaw), 0,
                Math.sin(yaw), Math.cos(yaw), 0,
                0, 0, 1,
        };
        double[] x = {
                1, 0, 0,
                0, Math.cos(pitch), -Math.sin(pitch),
                0, Math.sin(pitch), Math.cos(pitch),
        };
        double[] y = {
                Math.cos(roll), 0, Math.sin(roll),
                0, 1, 0,
                -Math.sin(roll), 0, Math.cos(roll),
        };
        double[] m = multiply(multiply(z, x), y);
        float[] result = new float[9];
        for (int i = 0; i < 9; i++) {
            result[i] = (float) m[i];
        }
        return result;
    }

    private static double[] multiply(double[] a, double[] b) {
        if (b.length == 3) {
            return new double[]{
                    a[0] * b[0] + a[1] * b[1] + a[2] * b[2],
                    a[3] * b[0] + a[4] * b[1] + a[5] * b[2],
                    a[6] * b[0] + a[7] * b[1] + a[8] * b[2],
            };
        }
        double[] result = new double[9];
        for (int row = 0; row < 3; row++) {
            for (int col = 0; col < 3; col++) {
                for (int k = 0; k < 3; k++) {
                    result[row * 3 + col] += a[row * 3 + k] * b[k * 3 + col];
                }
            }
        }
        return result;
    }

    private static double[] transpose(double[] m) {
        return new double[]{
                m[0], m[3], m[6],
                m[1], m[4], m[7],
                m[2], m[5], m[8],
        };
    }
}
