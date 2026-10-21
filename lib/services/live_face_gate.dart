/// Accumulates one continuous person's live frames before accepting a sample.
class LiveFaceGate {
  int _stableFrames = 0;
  int? _trackingId;
  int _blinkStage = 0;
  bool _challengePassed = false;

  void reset() {
    _stableFrames = 0;
    _trackingId = null;
    _blinkStage = 0;
    _challengePassed = false;
  }

  bool observe({
    required int faceCount,
    bool facingForward = false,
    bool matches = false,
    double? leftEye,
    double? rightEye,
    double? smile,
    int? trackingId,
  }) {
    if (faceCount != 1 || !facingForward || !matches) {
      reset();
      return false;
    }
    if (_trackingId != null && trackingId != _trackingId) reset();
    _trackingId = trackingId;
    _stableFrames++;
    if (leftEye != null && rightEye != null) {
      final average = (leftEye + rightEye) / 2;
      if (_blinkStage == 0 && average > .7) {
        _blinkStage = 1;
      } else if (_blinkStage == 1 && average < .25) {
        _blinkStage = 2;
      } else if (_blinkStage == 2 && average > .7) {
        _challengePassed = true;
      }
    }
    if (smile != null && smile >= .7) _challengePassed = true;
    return _stableFrames >= 3 && _challengePassed;
  }
}
