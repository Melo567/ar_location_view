import Flutter
import UIKit
import CoreLocation
import CoreMotion
import simd

/// Modern Swift implementation of AR Location View Plugin.
///
/// Uses Swift 5 features including improved error handling and cleaner syntax.
public class SwiftArLocationViewPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate {

    // MARK: - Properties

    private var eventSink: FlutterEventSink?
    private let locationManager: CLLocationManager
    private let motionManager: CMMotionManager

    // Configuration
    private let headingFilter: Double = 0.1
    private let motionUpdateInterval: TimeInterval = 1.0 / 30.0

    // MARK: - Initialization

    private init(channel: FlutterEventChannel) {
        locationManager = CLLocationManager()
        motionManager = CMMotionManager()

        super.init()

        setupLocationManager()
        setupMotionManager()
        channel.setStreamHandler(self)
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.headingFilter = headingFilter
    }

    private func setupMotionManager() {
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
    }

    // MARK: - FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterEventChannel(
            name: "pie/ar_view_location",
            binaryMessenger: registrar.messenger()
        )
        _ = SwiftArLocationViewPlugin(channel: channel)
    }

    // MARK: - FlutterStreamHandler

    public func onListen(
        withArguments arguments: Any?,
        eventSink: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = eventSink
        locationManager.startUpdatingHeading()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        locationManager.stopUpdatingHeading()
        return nil
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        guard newHeading.headingAccuracy > 0 else { return }

        let headingForCameraMode = calculateCameraHeading(
            trueHeading: newHeading.trueHeading
        )

        let sensorData: [Double] = [
            newHeading.trueHeading,
            headingForCameraMode,
            newHeading.headingAccuracy
        ]

        eventSink?(sensorData)
    }

    public func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        eventSink?(FlutterError(
            code: "LOCATION_ERROR",
            message: error.localizedDescription,
            details: nil
        ))
    }

    // MARK: - Heading Calculation

    /// Calculates the heading for camera mode using device motion data.
    ///
    /// Re-maps the device orientation matrix such that the Z axis (out the back
    /// of the device) always reads -90deg off magnetic north.
    private func calculateCameraHeading(trueHeading: Double) -> Double {
        guard let attitude = motionManager.deviceMotion?.attitude else {
            return trueHeading
        }

        // Rotation matrices for coordinate system remapping
        // -90 degrees around the Y axis
        let r1 = double3x3(rows: [
            simd_double3(0, 0, 1),
            simd_double3(0, 1, 0),
            simd_double3(-1, 0, 0)
        ])

        // -90 degrees around the Z axis
        let r2 = double3x3(rows: [
            simd_double3(0, -1, 0),
            simd_double3(1, 0, 0),
            simd_double3(0, 0, 1)
        ])

        // Device rotation matrix
        let rotationMatrix = attitude.rotationMatrix
        let R = double3x3(rows: [
            simd_double3(rotationMatrix.m11, rotationMatrix.m12, rotationMatrix.m13),
            simd_double3(rotationMatrix.m21, rotationMatrix.m22, rotationMatrix.m23),
            simd_double3(rotationMatrix.m31, rotationMatrix.m32, rotationMatrix.m33)
        ])

        // Combined transformation
        let T = r2 * r1 * R

        // Calculate yaw from rotation matrix and add 90 degrees
        let yaw = atan2(T[0, 1], T[1, 1]) + .pi / 2

        // Normalize to 0-360 degrees
        let normalizedYaw = (yaw + .pi * 2).truncatingRemainder(dividingBy: .pi * 2)
        return normalizedYaw * 180.0 / .pi
    }

    // MARK: - Cleanup

    deinit {
        motionManager.stopDeviceMotionUpdates()
        locationManager.stopUpdatingHeading()
    }
}

// MARK: - Sensor Availability Extension

extension SwiftArLocationViewPlugin {

    /// Checks if compass/heading is available on this device.
    public var isHeadingAvailable: Bool {
        CLLocationManager.headingAvailable()
    }

    /// Checks if device motion is available.
    public var isDeviceMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }
}
