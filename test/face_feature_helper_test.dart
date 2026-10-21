import 'package:flutter_test/flutter_test.dart';
import 'package:ngoc_truong_2380602415/services/face_feature_helper.dart';

void main() {
  group('FaceFeatureHelper Tests', () {
    test('Default similarityThreshold is 0.65', () {
      expect(FaceFeatureHelper.similarityThreshold, equals(0.65));
      expect(similarityThreshold, equals(0.65));
    });

    test('calculateSimilarity returns 1.0 for identical features', () {
      final sample = {
        'boxAspect': 0.75,
        'eyeDistRatio': 0.35,
        'eyeToNoseRatio': 0.25,
        'noseToMouthRatio': 0.20,
      };

      final sim = FaceFeatureHelper.calculateSimilarity(sample, sample);
      expect(sim, equals(1.0));
      expect(FaceFeatureHelper.isMatch(sample, sample), isTrue);
    });

    test('calculateSimilarity handles integer and double numeric values', () {
      final f1 = {
        'boxAspect': 1,
        'eyeDistRatio': 0.35,
        'eyeToNoseRatio': 0.25,
        'noseToMouthRatio': 0.20,
      };
      final f2 = {
        'boxAspect': 1.0,
        'eyeDistRatio': 0.35,
        'eyeToNoseRatio': 0.25,
        'noseToMouthRatio': 0.20,
      };

      final sim = FaceFeatureHelper.calculateSimilarity(f1, f2);
      expect(sim, equals(1.0));
    });

    test('calculateSimilarity calculates accurate score for slight differences', () {
      final f1 = {
        'boxAspect': 0.75,
        'eyeDistRatio': 0.35,
        'eyeToNoseRatio': 0.25,
        'noseToMouthRatio': 0.20,
      };
      // Diff on each key is 0.02 -> avgDiff = 0.02 -> sim = 1.0 - (0.02 * 3.0) = 0.94
      final f2 = {
        'boxAspect': 0.77,
        'eyeDistRatio': 0.37,
        'eyeToNoseRatio': 0.27,
        'noseToMouthRatio': 0.22,
      };

      final sim = FaceFeatureHelper.calculateSimilarity(f1, f2);
      expect(sim, closeTo(0.94, 0.001));
      expect(FaceFeatureHelper.isMatch(f1, f2), isTrue);
    });

    test('calculateSimilarity returns < 0.65 and isMatch returns false for large difference', () {
      final f1 = {
        'boxAspect': 0.50,
        'eyeDistRatio': 0.20,
        'eyeToNoseRatio': 0.15,
        'noseToMouthRatio': 0.10,
      };
      final f2 = {
        'boxAspect': 0.90,
        'eyeDistRatio': 0.45,
        'eyeToNoseRatio': 0.40,
        'noseToMouthRatio': 0.35,
      };

      final sim = FaceFeatureHelper.calculateSimilarity(f1, f2);
      expect(sim, lessThan(0.65));
      expect(FaceFeatureHelper.isMatch(f1, f2), isFalse);
    });

    test('calculateSimilarity clamps to 0.0 when differences are huge', () {
      final f1 = {
        'boxAspect': 0.1,
        'eyeDistRatio': 0.1,
        'eyeToNoseRatio': 0.1,
        'noseToMouthRatio': 0.1,
      };
      final f2 = {
        'boxAspect': 1.0,
        'eyeDistRatio': 1.0,
        'eyeToNoseRatio': 1.0,
        'noseToMouthRatio': 1.0,
      };

      final sim = FaceFeatureHelper.calculateSimilarity(f1, f2);
      expect(sim, equals(0.0));
    });

    test('calculateSimilarity returns 0.0 for empty or invalid maps', () {
      expect(FaceFeatureHelper.calculateSimilarity({}, {}), equals(0.0));
      expect(
        FaceFeatureHelper.calculateSimilarity({'invalidKey': 123}, {'otherKey': 456}),
        equals(0.0),
      );
    });

    test('isMatch returns true when sample is null', () {
      final features = {'boxAspect': 0.75};
      expect(FaceFeatureHelper.isMatch(features, null), isTrue);
    });

    test('top-level calculateSimilarity matches FaceFeatureHelper', () {
      final f1 = {'boxAspect': 0.8};
      final f2 = {'boxAspect': 0.8};
      expect(calculateSimilarity(f1, f2), equals(FaceFeatureHelper.calculateSimilarity(f1, f2)));
    });

    test('FaceLivenessResult factory constructors work correctly', () {
      final passed = FaceLivenessResult.passed('Liveness ok');
      expect(passed.isSuccess, isTrue);
      expect(passed.successDetail, equals('Liveness ok'));
      expect(passed.errorMessage, isNull);

      final failed = FaceLivenessResult.failed('Góc mặt lệch');
      expect(failed.isSuccess, isFalse);
      expect(failed.errorMessage, equals('Góc mặt lệch'));
      expect(failed.successDetail, isNull);
    });

    test('FaceLivenessChecker evaluates head angles and smiling', () {
      expect(
        FaceLivenessChecker.isHeadAngleDirect(yaw: 10.0, roll: -12.0, pitch: 0.0),
        isTrue,
      );
      expect(
        FaceLivenessChecker.isHeadAngleDirect(yaw: 16.0, roll: 0.0, pitch: 0.0),
        isFalse,
      );
      expect(FaceLivenessChecker.isSmiling(0.75), isTrue);
      expect(FaceLivenessChecker.isSmiling(0.5), isFalse);
      expect(FaceLivenessChecker.isSmiling(null), isFalse);
    });
  });
}
