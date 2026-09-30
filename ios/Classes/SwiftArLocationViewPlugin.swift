import AVFoundation
import Flutter
import UIKit
import CoreLocation
import CoreMotion
import simd

public class SwiftArLocationViewPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CLLocationManagerDelegate {

  private var eventSink: FlutterEventSink?;
  private var location: CLLocationManager = CLLocationManager();
  private var motion: CMMotionManager = CMMotionManager();

  private var lastHeading: Double = 0;
  private var lastHeadingForCameraMode: Double = 0;
  private var lastHeadingAccuracy: Double = -1;

  /// Whether `CMAttitude.rotationMatrix` must be transposed to map the
  /// reference frame to the device frame. Determined once from the gravity
  /// vector (see `resolveMatrixConvention`) rather than assumed.
  private var transposeAttitude: Bool? = nil;


  init(channel: FlutterEventChannel) {
      super.init()
      location.delegate = self
      location.headingFilter = 0.1;
      channel.setStreamHandler(self);

      motion.deviceMotionUpdateInterval = 1.0 / 60.0;
  }


  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel.init(name: "pie/ar_view_location", binaryMessenger: registrar.messenger())
    _ = SwiftArLocationViewPlugin(channel: channel);

    let cameraChannel = FlutterMethodChannel(name: "pie/ar_view_location/camera", binaryMessenger: registrar.messenger())
    cameraChannel.setMethodCallHandler { call, result in
        if call.method == "backCameraFieldOfView" {
            result(backCameraFieldOfView())
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
  }

  /// Field of view of the back wide camera along its long side, in degrees.
  private static func backCameraFieldOfView() -> Double? {
      guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
          return nil;
      }
      // `videoFieldOfView` is the horizontal FOV of the (landscape) sensor.
      let fov = Double(device.activeFormat.videoFieldOfView);
      return fov > 0 ? fov : nil;
  }

 public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
          self.eventSink = eventSink;
          // Motion updates are only needed while someone listens: running
          // them from plugin registration drained the battery for the whole
          // app lifetime.
          if motion.isDeviceMotionAvailable {
              let frames = CMMotionManager.availableAttitudeReferenceFrames();
              let frame: CMAttitudeReferenceFrame = frames.contains(.xTrueNorthZVertical)
                  ? .xTrueNorthZVertical
                  : .xMagneticNorthZVertical;
              motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] data, _ in
                  guard let self = self, let data = data else { return; }
                  self.emitAttitude(data);
              }
          }
          UIDevice.current.beginGeneratingDeviceOrientationNotifications();
          NotificationCenter.default.addObserver(
              self,
              selector: #selector(deviceOrientationDidChange),
              name: UIDevice.orientationDidChangeNotification,
              object: nil);
          deviceOrientationDidChange();
          location.startUpdatingHeading();
          return nil;
 }

      public func onCancel(withArguments arguments: Any?) -> FlutterError? {
          eventSink = nil;
          location.stopUpdatingHeading();
          motion.stopDeviceMotionUpdates();
          NotificationCenter.default.removeObserver(
              self, name: UIDevice.orientationDidChangeNotification, object: nil);
          UIDevice.current.endGeneratingDeviceOrientationNotifications();
          return nil;
      }

      /// CLHeading is relative to `headingOrientation` (portrait by default),
      /// so without this the heading is off by ±90° in landscape.
      @objc private func deviceOrientationDidChange() {
          let orientation = UIDevice.current.orientation;
          guard orientation.isPortrait || orientation.isLandscape,
                let headingOrientation = CLDeviceOrientation(rawValue: Int32(orientation.rawValue)) else {
              return;
          }
          location.headingOrientation = headingOrientation;
      }

      /// Sends `[heading, headingForCameraMode, accuracy, m0...m8]` where `m`
      /// is the row-major world (East, North, Up) -> screen rotation matrix
      /// expected by `ArSensor.rotationMatrix`.
      private func emitAttitude(_ data: CMDeviceMotion) {
          guard let sink = eventSink else { return; }
          let r = data.attitude.rotationMatrix;
          var m = simd_double3x3(rows: [
              simd_double3(r.m11, r.m12, r.m13),
              simd_double3(r.m21, r.m22, r.m23),
              simd_double3(r.m31, r.m32, r.m33),
          ]);
          if resolveMatrixConvention(m, gravity: data.gravity) {
              m = m.transpose;
          }
          // Reference frame is (North, West, Up): convert from (East, North, Up).
          let enuToReference = simd_double3x3(rows: [
              simd_double3(0, 1, 0),
              simd_double3(-1, 0, 0),
              simd_double3(0, 0, 1),
          ]);
          let worldToScreen = deviceToScreen() * m * enuToReference;
          var payload = [lastHeading, lastHeadingForCameraMode, lastHeadingAccuracy];
          for row in 0..<3 {
              for col in 0..<3 {
                  payload.append(worldToScreen[col, row]);
              }
          }
          sink(payload);
      }

      /// Picks the matrix convention whose "down" direction matches the
      /// measured gravity (device frame). Locked once the answer is clear, so
      /// it cannot flip between samples. Both conventions agree on "down" in
      /// some poses (e.g. lying flat): until then, assume the documented one
      /// (reference -> device) without locking it.
      private func resolveMatrixConvention(_ m: simd_double3x3, gravity: CMAcceleration) -> Bool {
          if let transpose = transposeAttitude { return transpose; }
          let g = simd_normalize(simd_double3(gravity.x, gravity.y, gravity.z));
          let down = simd_double3(0, 0, -1);
          // Reference "down" expressed in the device frame for each convention.
          let errorDirect = simd_length(m * down - g);
          let errorTransposed = simd_length(m.transpose * down - g);
          guard abs(errorDirect - errorTransposed) > 0.3 else { return false; }
          let transpose = errorTransposed < errorDirect;
          transposeAttitude = transpose;
          return transpose;
      }

      /// Rotation from the portrait device frame to the current UI frame
      /// (x right, y up of the displayed screen).
      private func deviceToScreen() -> simd_double3x3 {
          let orientation: UIInterfaceOrientation;
          if #available(iOS 13.0, *) {
              orientation = UIApplication.shared.connectedScenes
                  .compactMap { $0 as? UIWindowScene }
                  .first?.interfaceOrientation ?? .portrait;
          } else {
              orientation = UIApplication.shared.statusBarOrientation;
          }
          switch orientation {
          case .landscapeRight:
              // Device top points left: screen right = device -y, up = device x.
              return simd_double3x3(rows: [
                  simd_double3(0, -1, 0),
                  simd_double3(1, 0, 0),
                  simd_double3(0, 0, 1),
              ]);
          case .landscapeLeft:
              return simd_double3x3(rows: [
                  simd_double3(0, 1, 0),
                  simd_double3(-1, 0, 0),
                  simd_double3(0, 0, 1),
              ]);
          case .portraitUpsideDown:
              return simd_double3x3(rows: [
                  simd_double3(-1, 0, 0),
                  simd_double3(0, -1, 0),
                  simd_double3(0, 0, 1),
              ]);
          default:
              return matrix_identity_double3x3;
          }
      }

      public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
          if (newHeading.headingAccuracy>0){
              // trueHeading is negative when it cannot be computed (location
              // unavailable): fall back to the magnetic heading.
              let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading;
              var headingForCameraMode = heading;
              // If device orientation data is available, use it to calculate the heading out the the
              // back of the device (rather than out the top of the device).
              if let data = self.motion.deviceMotion?.attitude {
                  // Re-map the device orientation matrix such that the Z axis (out the back of the device)
                  // always reads -90deg off magnetic north. All rotation matrices use + rotation to mean
                  // counter-clockwise.
                  let r1 = double3x3(rows: [
                      simd_double3(0, 0, 1),
                      simd_double3(0, 1, 0),
                      simd_double3(-1, 0, 0)
                  ]); // -90 around the Y axis
                  let r2 = double3x3(rows: [
                      simd_double3(0, -1, 0),
                      simd_double3(1, 0, 0),
                      simd_double3(0, 0, 1)
                  ]); // -90 around the Z axis
                  let R = double3x3(rows: [
                      simd_double3(data.rotationMatrix.m11, data.rotationMatrix.m12, data.rotationMatrix.m13),
                      simd_double3(data.rotationMatrix.m21, data.rotationMatrix.m22, data.rotationMatrix.m23),
                      simd_double3(data.rotationMatrix.m31, data.rotationMatrix.m32, data.rotationMatrix.m33)
                  ]);
                  let T = r2 * r1 * R;
                  // Calculate yaw from R and add 90deg.
                  let yaw = atan2(T[0, 1], T[1, 1]) + Double.pi / 2;
                  headingForCameraMode = (yaw + Double.pi * 2).truncatingRemainder(dividingBy: Double.pi * 2) * 180.0 / Double.pi;
              }
              lastHeading = heading;
              lastHeadingForCameraMode = headingForCameraMode;
              lastHeadingAccuracy = newHeading.headingAccuracy;
              // Without motion data, the heading alone is still useful; with
              // it, `emitAttitude` already streams at a higher rate.
              if !motion.isDeviceMotionActive {
                  eventSink?([heading, headingForCameraMode, newHeading.headingAccuracy]);
              }
          }
      }
}
