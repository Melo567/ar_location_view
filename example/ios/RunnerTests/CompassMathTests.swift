import simd
import UIKit
import XCTest

@testable import ar_location_view

final class CompassMathTests: XCTestCase {
    private let accuracy = 1e-9

    func testOrientationCodesAreTheIndexesOfFlutterDeviceOrientation() {
        // DeviceOrientation.values: portraitUp, landscapeLeft, portraitDown,
        // landscapeRight. UIInterfaceOrientation left/right are swapped.
        XCTAssertEqual(CompassMath.orientationCode(.portrait), 0);
        XCTAssertEqual(CompassMath.orientationCode(.landscapeRight), 1);
        XCTAssertEqual(CompassMath.orientationCode(.portraitUpsideDown), 2);
        XCTAssertEqual(CompassMath.orientationCode(.landscapeLeft), 3);
        XCTAssertEqual(CompassMath.orientationCode(.unknown), -1);
    }

    func testDeviceToScreenInPortraitIsTheIdentity() {
        assertEqual(CompassMath.deviceToScreen(.portrait), matrix_identity_double3x3);
    }

    func testDeviceToScreenInLandscapeRight() {
        // Device top points left: the device's x axis is the screen's up.
        let m = CompassMath.deviceToScreen(.landscapeRight);

        assertEqual(m * simd_double3(1, 0, 0), simd_double3(0, 1, 0));
        assertEqual(m * simd_double3(0, 1, 0), simd_double3(-1, 0, 0));
    }

    func testDeviceToScreenInLandscapeLeft() {
        let m = CompassMath.deviceToScreen(.landscapeLeft);

        assertEqual(m * simd_double3(1, 0, 0), simd_double3(0, -1, 0));
        assertEqual(m * simd_double3(0, 1, 0), simd_double3(1, 0, 0));
    }

    func testDeviceToScreenIsAProperRotationInEveryOrientation() {
        let orientations: [UIInterfaceOrientation] = [
            .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight, .unknown,
        ];
        for orientation in orientations {
            let m = CompassMath.deviceToScreen(orientation);
            assertEqual(m * m.transpose, matrix_identity_double3x3);
            XCTAssertEqual(simd_determinant(m), 1, accuracy: accuracy);
        }
    }

    func testNeedsTransposeFollowsTheGravity() {
        let referenceToDevice = rotation(yaw: 0.4, pitch: 1.1, roll: -0.3);
        // Gravity measured in the device frame.
        let gravity = referenceToDevice * simd_double3(0, 0, -1);

        XCTAssertEqual(CompassMath.needsTranspose(referenceToDevice, gravity: gravity), false);
        XCTAssertEqual(
            CompassMath.needsTranspose(referenceToDevice.transpose, gravity: gravity), true);
    }

    func testNeedsTransposeIsUndecidedWhenLyingFlat() {
        // A rotation around the vertical axis only: both conventions see the
        // same "down".
        let referenceToDevice = rotation(yaw: 0.8, pitch: 0, roll: 0);
        let gravity = simd_double3(0, 0, -9.81);

        XCTAssertNil(CompassMath.needsTranspose(referenceToDevice, gravity: gravity));
    }

    func testWorldToScreenMapsEastOppositeToWest() {
        // Device frame aligned with the reference frame (North, West, Up):
        // east is the device's -y axis, i.e. the screen's -y in portrait.
        let m = CompassMath.worldToScreen(
            referenceToDevice: matrix_identity_double3x3, orientation: .portrait);

        assertEqual(m * simd_double3(1, 0, 0), simd_double3(0, -1, 0));
        assertEqual(m * simd_double3(0, 1, 0), simd_double3(1, 0, 0));
        assertEqual(m * simd_double3(0, 0, 1), simd_double3(0, 0, 1));
    }

    func testWorldToScreenIsAProperRotation() {
        let m = CompassMath.worldToScreen(
            referenceToDevice: rotation(yaw: -2.1, pitch: 0.6, roll: 0.9),
            orientation: .landscapeRight);

        assertEqual(m * m.transpose, matrix_identity_double3x3);
        XCTAssertEqual(simd_determinant(m), 1, accuracy: 1e-6);
    }

    func testPayloadIsRowMajorWithTheOrientationLast() {
        let m = simd_double3x3(rows: [
            simd_double3(1, 2, 3),
            simd_double3(4, 5, 6),
            simd_double3(7, 8, 9),
        ]);

        let payload = CompassMath.payload(
            heading: 42, headingForCameraMode: 43, accuracy: 15,
            worldToScreen: m, orientation: .landscapeLeft);

        XCTAssertEqual(payload, [42, 43, 15, 1, 2, 3, 4, 5, 6, 7, 8, 9, 3]);
    }

    func testPayloadWithoutMatrix() {
        let payload = CompassMath.payload(
            heading: 42, headingForCameraMode: 43, accuracy: 15,
            worldToScreen: nil, orientation: .portrait);

        XCTAssertEqual(payload, [42, 43, 15, 0]);
    }

    // MARK: - Helpers

    private func rotation(yaw: Double, pitch: Double, roll: Double) -> simd_double3x3 {
        let z = simd_double3x3(rows: [
            simd_double3(cos(yaw), -sin(yaw), 0),
            simd_double3(sin(yaw), cos(yaw), 0),
            simd_double3(0, 0, 1),
        ]);
        let x = simd_double3x3(rows: [
            simd_double3(1, 0, 0),
            simd_double3(0, cos(pitch), -sin(pitch)),
            simd_double3(0, sin(pitch), cos(pitch)),
        ]);
        let y = simd_double3x3(rows: [
            simd_double3(cos(roll), 0, sin(roll)),
            simd_double3(0, 1, 0),
            simd_double3(-sin(roll), 0, cos(roll)),
        ]);
        return z * x * y;
    }

    private func assertEqual(
        _ a: simd_double3, _ b: simd_double3, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertLessThan(simd_length(a - b), 1e-6, "\(a) != \(b)", file: file, line: line);
    }

    private func assertEqual(
        _ a: simd_double3x3, _ b: simd_double3x3,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        for col in 0..<3 {
            assertEqual(a[col], b[col], file: file, line: line);
        }
    }
}
