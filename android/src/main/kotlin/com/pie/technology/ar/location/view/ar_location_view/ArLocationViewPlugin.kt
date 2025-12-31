package com.pie.technology.ar.location.view.ar_location_view

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.SystemClock
import android.util.Log
import android.view.Display
import android.view.Surface
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import kotlin.math.PI

/**
 * ArLocationViewPlugin - Modern Kotlin implementation with improved sensor handling.
 *
 * Uses Kotlin features for cleaner code and better null safety.
 */
class ArLocationViewPlugin : FlutterPlugin, StreamHandler {

    companion object {
        private const val TAG = "ArLocationView"
        private const val ALPHA = 0.45f
        private const val COMPASS_UPDATE_RATE_MS = 10L
        private const val CHANNEL_NAME = "pie/ar_view_location"

        // Calibration status constants matching SensorManager accuracy
        const val CALIBRATION_STATUS_UNRELIABLE = 0
        const val CALIBRATION_STATUS_LOW = 1
        const val CALIBRATION_STATUS_MEDIUM = 2
        const val CALIBRATION_STATUS_HIGH = 3
    }

    private var display: Display? = null
    private var sensorManager: SensorManager? = null
    private var sensorEventListener: SensorEventListener? = null

    private var compassSensor: Sensor? = null
    private var gravitySensor: Sensor? = null
    private var magneticFieldSensor: Sensor? = null

    private val truncatedRotationVectorValue = FloatArray(4)
    private val rotationMatrix = FloatArray(9)
    private var rotationVectorValue: FloatArray? = null
    private var lastHeading = 0f
    private var lastAccuracySensorStatus = SensorManager.SENSOR_STATUS_ACCURACY_HIGH

    private var compassUpdateNextTimestamp = 0L
    private var gravityValues = FloatArray(3)
    private var magneticValues = FloatArray(3)

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        initializeSensors(context)

        val channel = EventChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        cleanup()
    }

    private fun initializeSensors(context: Context) {
        display = (context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager)
            .getDisplay(Display.DEFAULT_DISPLAY)

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

        sensorManager?.let { manager ->
            compassSensor = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            if (compassSensor == null) {
                Log.d(TAG, "Rotation vector sensor not supported, falling back to accelerometer and magnetic field.")
            }

            gravitySensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            magneticFieldSensor = manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        }
    }

    override fun onListen(arguments: Any?, events: EventSink?) {
        events ?: return

        sensorEventListener = createSensorEventListener(events)

        sensorManager?.apply {
            compassSensor?.let {
                registerListener(sensorEventListener, it, SensorManager.SENSOR_DELAY_GAME)
            }
            gravitySensor?.let {
                registerListener(sensorEventListener, it, SensorManager.SENSOR_DELAY_GAME)
            }
            magneticFieldSensor?.let {
                registerListener(sensorEventListener, it, SensorManager.SENSOR_DELAY_GAME)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorEventListener?.let { listener ->
            sensorManager?.apply {
                compassSensor?.let { unregisterListener(listener, it) }
                gravitySensor?.let { unregisterListener(listener, it) }
                magneticFieldSensor?.let { unregisterListener(listener, it) }
            }
        }
        sensorEventListener = null
    }

    private fun cleanup() {
        onCancel(null)
        sensorManager = null
        display = null
    }

    private val isCompassSensorAvailable: Boolean
        get() = compassSensor != null

    private fun createSensorEventListener(events: EventSink): SensorEventListener {
        return object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (lastAccuracySensorStatus == SensorManager.SENSOR_STATUS_UNRELIABLE) {
                    Log.d(TAG, "Compass sensor is unreliable, device calibration is needed.")
                }

                when (event.sensor.type) {
                    Sensor.TYPE_ROTATION_VECTOR -> {
                        rotationVectorValue = getRotationVectorFromSensorEvent(event)
                        updateOrientation(events)
                    }
                    Sensor.TYPE_ACCELEROMETER -> {
                        if (!isCompassSensorAvailable) {
                            gravityValues = lowPassFilter(
                                getRotationVectorFromSensorEvent(event),
                                gravityValues
                            )
                            updateOrientation(events)
                        }
                    }
                    Sensor.TYPE_MAGNETIC_FIELD -> {
                        if (!isCompassSensorAvailable) {
                            magneticValues = lowPassFilter(
                                getRotationVectorFromSensorEvent(event),
                                magneticValues
                            )
                            updateOrientation(events)
                        }
                    }
                }
            }

            override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
                if (lastAccuracySensorStatus != accuracy) {
                    lastAccuracySensorStatus = accuracy
                }
            }
        }
    }

    private fun updateOrientation(events: EventSink) {
        val currentTime = SystemClock.elapsedRealtime()
        if (currentTime < compassUpdateNextTimestamp) {
            return
        }

        val rotationVector = rotationVectorValue
        if (rotationVector != null) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, rotationVector)
        } else {
            SensorManager.getRotationMatrix(rotationMatrix, null, gravityValues, magneticValues)
        }

        val rotation = display?.rotation ?: Surface.ROTATION_0
        var (worldAxisX, worldAxisY) = getWorldAxesForRotation(rotation)

        val adjustedRotationMatrix = FloatArray(9)
        SensorManager.remapCoordinateSystem(
            rotationMatrix,
            worldAxisX,
            worldAxisY,
            adjustedRotationMatrix
        )

        val orientation = FloatArray(3)
        SensorManager.getOrientation(adjustedRotationMatrix, orientation)

        // Adjust axes based on pitch and roll
        val (newAxisX, newAxisY) = adjustAxesForOrientation(orientation, rotation)
        if (newAxisX != worldAxisX || newAxisY != worldAxisY) {
            worldAxisX = newAxisX
            worldAxisY = newAxisY
            SensorManager.remapCoordinateSystem(
                rotationMatrix,
                worldAxisX,
                worldAxisY,
                adjustedRotationMatrix
            )
            SensorManager.getOrientation(adjustedRotationMatrix, orientation)
        }

        // Convert sensor accuracy to calibration status
        val calibrationStatus = when (lastAccuracySensorStatus) {
            SensorManager.SENSOR_STATUS_ACCURACY_HIGH -> CALIBRATION_STATUS_HIGH
            SensorManager.SENSOR_STATUS_ACCURACY_MEDIUM -> CALIBRATION_STATUS_MEDIUM
            SensorManager.SENSOR_STATUS_ACCURACY_LOW -> CALIBRATION_STATUS_LOW
            else -> CALIBRATION_STATUS_UNRELIABLE
        }

        val heading = DoubleArray(4).apply {
            this[0] = Math.toDegrees(orientation[0].toDouble())
            this[1] = 0.0 // headingForCameraMode (calculated on iOS side)
            this[2] = lastAccuracySensorStatus.toDouble()
            this[3] = calibrationStatus.toDouble() // Calibration status for Flutter
        }

        events.success(heading.toList())
        lastHeading = heading[0].toFloat()
        compassUpdateNextTimestamp = currentTime + COMPASS_UPDATE_RATE_MS
    }

    private fun getWorldAxesForRotation(rotation: Int): Pair<Int, Int> {
        return when (rotation) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
    }

    private fun adjustAxesForOrientation(
        orientation: FloatArray,
        rotation: Int
    ): Pair<Int, Int> {
        val pitch = orientation[1]
        val roll = orientation[2]

        return when {
            pitch < -PI / 4 -> {
                // Device screen parallel to ground, facing up
                when (rotation) {
                    Surface.ROTATION_90 -> SensorManager.AXIS_Z to SensorManager.AXIS_MINUS_X
                    Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Z
                    Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Z to SensorManager.AXIS_X
                    else -> SensorManager.AXIS_X to SensorManager.AXIS_Z
                }
            }
            pitch > PI / 4 -> {
                // Device screen upside down
                when (rotation) {
                    Surface.ROTATION_90 -> SensorManager.AXIS_MINUS_Z to SensorManager.AXIS_MINUS_X
                    Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_Z
                    Surface.ROTATION_270 -> SensorManager.AXIS_Z to SensorManager.AXIS_X
                    else -> SensorManager.AXIS_X to SensorManager.AXIS_MINUS_Z
                }
            }
            kotlin.math.abs(roll) > PI / 2 -> {
                // Device face down
                when (rotation) {
                    Surface.ROTATION_90 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_MINUS_X
                    Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_Y
                    Surface.ROTATION_270 -> SensorManager.AXIS_Y to SensorManager.AXIS_X
                    else -> SensorManager.AXIS_X to SensorManager.AXIS_MINUS_Y
                }
            }
            else -> getWorldAxesForRotation(rotation)
        }
    }

    private fun lowPassFilter(newValues: FloatArray, smoothedValues: FloatArray): FloatArray {
        for (i in newValues.indices) {
            smoothedValues[i] = smoothedValues[i] + ALPHA * (newValues[i] - smoothedValues[i])
        }
        return smoothedValues
    }

    private fun getRotationVectorFromSensorEvent(event: SensorEvent): FloatArray {
        return if (event.values.size > 4) {
            // Samsung device workaround for Android 4.3
            System.arraycopy(event.values, 0, truncatedRotationVectorValue, 0, 4)
            truncatedRotationVectorValue
        } else {
            event.values
        }
    }
}
