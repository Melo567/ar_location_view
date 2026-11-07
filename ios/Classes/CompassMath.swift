import simd
import UIKit

/// Pure computations behind the compass events, kept free of CoreMotion and
/// UIKit state so they can be unit tested.
enum CompassMath {
    /// CoreMotion's reference frame is (North, West, Up): converts a vector
    /// from (East, North, Up) to it.
    static let enuToReference = simd_double3x3(rows: [
        simd_double3(0, 1, 0),
        simd_double3(-1, 0, 0),
        simd_double3(0, 0, 1),
    ]);

    /// Index of Flutter's `DeviceOrientation` (0 portraitUp, 1 landscapeLeft,
    /// 2 portraitDown, 3 landscapeRight), or -1 when unknown. Left and right
    /// are swapped: `UIInterfaceOrientation` is the rotation needed to get
    /// back to portrait, not the rotation of the device (same mapping as
    /// the native_device_orientation plugin).
    static func orientationCode(_ orientation: UIInterfaceOrientation) -> Double {
        switch orientation {
        case .portrait: return 0;
        case .landscapeRight: return 1;
        case .portraitUpsideDown: return 2;
        case .landscapeLeft: return 3;
        default: return -1;
        }
    }

    /// Rotation from the portrait device frame to the UI frame (x right,
    /// y up of the displayed screen).
    static func deviceToScreen(_ orientation: UIInterfaceOrientation) -> simd_double3x3 {
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

    /// Whether the attitude matrix `m` must be transposed to map the
    /// reference frame to the device frame: picks the convention whose
    /// "down" direction matches the measured `gravity` (device frame). Nil
    /// while both conventions agree on "down" (e.g. lying flat).
    static func needsTranspose(_ m: simd_double3x3, gravity: simd_double3) -> Bool? {
        let g = simd_normalize(gravity);
        let down = simd_double3(0, 0, -1);
        // Reference "down" expressed in the device frame for each convention.
        let errorDirect = simd_length(m * down - g);
        let errorTransposed = simd_length(m.transpose * down - g);
        guard abs(errorDirect - errorTransposed) > 0.3 else { return nil; }
        return errorTransposed < errorDirect;
    }

    /// World (East, North, Up) -> UI screen rotation, from the attitude
    /// `referenceToDevice` (reference frame -> portrait device frame).
    static func worldToScreen(
        referenceToDevice: simd_double3x3,
        orientation: UIInterfaceOrientation
    ) -> simd_double3x3 {
        return deviceToScreen(orientation) * referenceToDevice * enuToReference;
    }

    /// `[heading, headingForCameraMode, accuracy, m0...m8, orientation]`,
    /// where `m` is `worldToScreen` in row-major order, or
    /// `[heading, headingForCameraMode, accuracy, orientation]` without it.
    static func payload(
        heading: Double,
        headingForCameraMode: Double,
        accuracy: Double,
        worldToScreen: simd_double3x3?,
        orientation: UIInterfaceOrientation
    ) -> [Double] {
        var payload = [heading, headingForCameraMode, accuracy];
        if let m = worldToScreen {
            for row in 0..<3 {
                for col in 0..<3 {
                    // simd subscripts are [column, row].
                    payload.append(m[col, row]);
                }
            }
        }
        payload.append(orientationCode(orientation));
        return payload;
    }
}
