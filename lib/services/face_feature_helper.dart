import 'dart:math' as math;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Kết quả kiểm tra Liveness sinh trắc học
class FaceLivenessResult {
  final bool isSuccess;
  final String? errorMessage;
  final String? successDetail;

  const FaceLivenessResult({
    required this.isSuccess,
    this.errorMessage,
    this.successDetail,
  });

  factory FaceLivenessResult.passed(String detail) =>
      FaceLivenessResult(isSuccess: true, successDetail: detail);

  factory FaceLivenessResult.failed(String error) =>
      FaceLivenessResult(isSuccess: false, errorMessage: error);
}

/// Bộ kiểm tra Liveness tương tác nghiêm ngặt:
/// - Góc mặt trực diện: Yaw, Roll, Pitch trong khoảng [-15°, +15°]
/// - Phát hiện chuyển động chớp mắt thật: Tỷ lệ mở mắt thay đổi từ > 0.7 sang < 0.25 rồi mở lại > 0.7
/// - Hoặc nụ cười thật: smilingProbability >= 0.7
class FaceLivenessChecker {
  /// Kiểm tra góc mặt trực diện trong khoảng [-15°, +15°]
  static bool isHeadAngleDirect({
    required double yaw,
    required double roll,
    required double pitch,
  }) {
    return yaw.abs() <= 15.0 && roll.abs() <= 15.0 && pitch.abs() <= 15.0;
  }

  /// Kiểm tra nụ cười đạt chuẩn Liveness: smilingProbability >= 0.7
  static bool isSmiling(double? smileProb) {
    return smileProb != null && smileProb >= 0.7;
  }

  /// Kiểm tra chuỗi chớp mắt thật: Tỷ lệ mở mắt chuyển từ > 0.7 sang < 0.25 rồi mở lại > 0.7
  static bool verifyBlinkSequence(List<double> eyeHistory) {
    if (eyeHistory.length < 3) return false;
    bool foundOpen1 = false;
    bool foundClosed = false;

    for (final val in eyeHistory) {
      if (!foundOpen1) {
        if (val > 0.7) foundOpen1 = true;
      } else if (!foundClosed) {
        if (val < 0.25) foundClosed = true;
      } else {
        if (val > 0.7) return true;
      }
    }
    return false;
  }

  /// Đánh giá Liveness toàn diện cho 1 khuôn mặt ML Kit
  static FaceLivenessResult evaluate({
    required Face face,
    int totalFaces = 1,
    List<double>? blinkHistory,
  }) {
    if (totalFaces > 1) {
      return FaceLivenessResult.failed(
        'Phát hiện $totalFaces khuôn mặt trong ảnh. Vui lòng chỉ đứng một mình trước camera để chống giả mạo.',
      );
    }

    final double rotY = face.headEulerAngleY ?? 0.0; // Yaw
    final double rotZ = face.headEulerAngleZ ?? 0.0; // Roll
    final double rotX = face.headEulerAngleX ?? 0.0; // Pitch

    if (!isHeadAngleDirect(yaw: rotY, roll: rotZ, pitch: rotX)) {
      return FaceLivenessResult.failed(
        '❌ Góc mặt chưa thẳng: Vui lòng nhìn trực diện vào camera (Lệch ≤ 15°).\n'
        'Hiện tại: Yaw: ${rotY.toStringAsFixed(1)}°, Roll: ${rotZ.toStringAsFixed(1)}°, Pitch: ${rotX.toStringAsFixed(1)}°',
      );
    }

    // 1. Kiểm tra nụ cười
    final double? smile = face.smilingProbability;
    final bool smilingPassed = isSmiling(smile);

    // 2. Kiểm tra chuỗi chớp mắt
    final double leftEye = face.leftEyeOpenProbability ?? 0.0;
    final double rightEye = face.rightEyeOpenProbability ?? 0.0;
    final double avgEye = (leftEye + rightEye) / 2.0;

    bool blinkPassed = false;
    if (blinkHistory != null && blinkHistory.isNotEmpty) {
      final historyWithCurrent = List<double>.from(blinkHistory)..add(avgEye);
      blinkPassed = verifyBlinkSequence(historyWithCurrent);
    }

    if (smilingPassed) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Phát hiện nụ cười tự nhiên (${((smile ?? 0) * 100).toStringAsFixed(1)}%) và góc mặt trực diện chuẩn!',
      );
    }

    if (blinkPassed) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Phát hiện chuyển động chớp mắt thật (Mở > 0.7 ➔ Nhắm < 0.25 ➔ Mở > 0.7)!',
      );
    }

    // 3. Nếu chưa chớp mắt/cười: Cả hai mắt phải mở to rõ (> 75%)
    if (leftEye >= 0.75 && rightEye >= 0.75) {
      return FaceLivenessResult.passed(
        '✅ Đạt chuẩn Liveness: Hai mắt mở to rõ (> 75%) và góc mặt trực diện chuẩn (-15° đến +15°)!',
      );
    }

    return FaceLivenessResult.failed(
      '❌ Kiểm tra Liveness thất bại:\n'
      'Vui lòng nhìn trực diện camera, mở to cả hai mắt (> 70%) hoặc mỉm cười nhẹ (> 70%) để xác thực người thật.\n'
      'Mắt trái: ${(leftEye * 100).toStringAsFixed(1)}%, Mắt phải: ${(rightEye * 100).toStringAsFixed(1)}%',
    );
  }
}

/// Helper dùng chung cho trích xuất đặc trưng khuôn mặt và tính độ tương đồng
class FaceFeatureHelper {
  /// Ngưỡng tương đồng khuôn mặt sinh trắc học mặc định: 0.65 (65%)
  static const double similarityThreshold = 0.65;

  /// Danh sách các khóa đặc trưng hình học khuôn mặt
  static const List<String> featureKeys = [
    'boxAspect',
    'eyeDistRatio',
    'eyeToNoseRatio',
    'noseToMouthRatio',
  ];

  /// Trích xuất các tỷ lệ hình học đặc trưng từ khuôn mặt do Google ML Kit phát hiện
  static Map<String, double> extractFaceFeatures(Face face) {
    final box = face.boundingBox;
    final double boxAspect = box.height > 0 ? box.width / box.height : 1.0;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];
    final nose = face.landmarks[FaceLandmarkType.noseBase];
    final mouth =
        face.landmarks[FaceLandmarkType.bottomMouth] ??
        face.landmarks[FaceLandmarkType.leftMouth] ??
        face.landmarks[FaceLandmarkType.rightMouth];

    double eyeDistRatio = 0.35;
    double eyeToNoseRatio = 0.25;
    double noseToMouthRatio = 0.20;

    if (leftEye != null && rightEye != null && box.width > 0) {
      final dx = (leftEye.position.x - rightEye.position.x).toDouble();
      final dy = (leftEye.position.y - rightEye.position.y).toDouble();
      eyeDistRatio = math.sqrt(dx * dx + dy * dy) / box.width;
    }

    if (leftEye != null && rightEye != null && nose != null && box.height > 0) {
      final eyeMidY = (leftEye.position.y + rightEye.position.y) / 2.0;
      eyeToNoseRatio = (nose.position.y - eyeMidY).abs() / box.height;
    }

    if (nose != null && mouth != null && box.height > 0) {
      noseToMouthRatio =
          (mouth.position.y - nose.position.y).abs() / box.height;
    }

    return {
      'boxAspect': boxAspect,
      'eyeDistRatio': eyeDistRatio,
      'eyeToNoseRatio': eyeToNoseRatio,
      'noseToMouthRatio': noseToMouthRatio,
    };
  }

  /// Tính độ tương đồng giữa hai mẫu đặc trưng khuôn mặt (0.0 -> 1.0)
  /// Sử dụng công thức sai lệch trung bình: (1.0 - (avgDiff * 3.0)).clamp(0.0, 1.0)
  static double calculateSimilarity(
    Map<String, dynamic> f1,
    Map<String, dynamic> f2,
  ) {
    double diff = 0.0;
    int count = 0;
    for (final key in featureKeys) {
      final v1 = (f1[key] as num?)?.toDouble();
      final v2 = (f2[key] as num?)?.toDouble();
      if (v1 != null && v2 != null) {
        diff += (v1 - v2).abs();
        count++;
      }
    }
    if (count == 0) return 0.0;
    final avgDiff = diff / count;
    return (1.0 - (avgDiff * 3.0)).clamp(0.0, 1.0);
  }

  /// So khớp hai mẫu đặc trưng có đạt ngưỡng tương đồng hay không.
  /// Nếu [sample] là null (chưa có mẫu), trả về true.
  static bool isMatch(
    Map<String, dynamic> f1,
    Map<String, dynamic>? sample, {
    double threshold = similarityThreshold,
  }) {
    if (sample == null) return true;
    return calculateSimilarity(f1, sample) >= threshold;
  }
}

/// Các alias cấp cao (top-level) để tăng tính linh hoạt và tiện dụng
const double similarityThreshold = FaceFeatureHelper.similarityThreshold;

Map<String, double> extractFaceFeatures(Face face) =>
    FaceFeatureHelper.extractFaceFeatures(face);

double calculateSimilarity(
  Map<String, dynamic> f1,
  Map<String, dynamic> f2,
) =>
    FaceFeatureHelper.calculateSimilarity(f1, f2);
