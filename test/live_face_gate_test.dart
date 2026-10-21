import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/services/live_face_gate.dart';

void main() {
  test('Live face requires stable matching frames and a smile or blink', () {
    final gate = LiveFaceGate();
    for (var i = 0; i < 5; i++) {
      expect(
        gate.observe(
          faceCount: 1,
          facingForward: true,
          matches: true,
          leftEye: .9,
          rightEye: .9,
        ),
        isFalse,
      );
    }
    expect(
      gate.observe(faceCount: 1, facingForward: true, matches: true, smile: .9),
      isTrue,
    );
  });
  test('A complete blink passes after three matching frames', () {
    final gate = LiveFaceGate();
    expect(
      gate.observe(
        faceCount: 1,
        facingForward: true,
        matches: true,
        leftEye: .9,
        rightEye: .9,
      ),
      isFalse,
    );
    expect(
      gate.observe(
        faceCount: 1,
        facingForward: true,
        matches: true,
        leftEye: .1,
        rightEye: .1,
      ),
      isFalse,
    );
    expect(
      gate.observe(
        faceCount: 1,
        facingForward: true,
        matches: true,
        leftEye: .9,
        rightEye: .9,
      ),
      isTrue,
    );
  });
  test('Multiple faces or a mismatch discard previous liveness', () {
    final gate = LiveFaceGate();
    gate.observe(faceCount: 1, facingForward: true, matches: true, smile: .9);
    gate.observe(faceCount: 2);
    expect(
      gate.observe(faceCount: 1, facingForward: true, matches: true),
      isFalse,
    );
    gate.observe(faceCount: 1, facingForward: true, matches: false);
    expect(
      gate.observe(faceCount: 1, facingForward: true, matches: true),
      isFalse,
    );
  });
  test('Changing tracked person resets previous blink sequence', () {
    final gate = LiveFaceGate();
    gate.observe(
      faceCount: 1,
      facingForward: true,
      matches: true,
      trackingId: 1,
      leftEye: .9,
      rightEye: .9,
    );
    gate.observe(
      faceCount: 1,
      facingForward: true,
      matches: true,
      trackingId: 1,
      leftEye: .1,
      rightEye: .1,
    );
    expect(
      gate.observe(
        faceCount: 1,
        facingForward: true,
        matches: true,
        trackingId: 2,
        leftEye: .9,
        rightEye: .9,
      ),
      isFalse,
    );
  });
}
