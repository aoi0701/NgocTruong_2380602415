import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ngoc_truong_2380602415/models/attendance.dart';
import 'package:ngoc_truong_2380602415/screens/biometric_qr_screen.dart';
import 'package:ngoc_truong_2380602415/services/attendance_service.dart';

class _Service extends AttendanceService {
  final calls = <String>[];
  Completer<AttendanceResult>? pending;
  @override
  Future<AttendanceResult> checkIn({
    required String method,
    double? latitude,
    double? longitude,
    String? qrToken,
    String? faceProof,
    String? locationName,
    String? notes,
  }) async {
    calls.add('in:$method:$qrToken');
    return pending == null
        ? AttendanceResult(success: true, message: 'OK')
        : pending!.future;
  }

  @override
  Future<AttendanceResult> checkOut({
    required String method,
    double? latitude,
    double? longitude,
    String? qrToken,
    String? faceProof,
    String? locationName,
    String? notes,
  }) async {
    calls.add('out:$method:$qrToken');
    return AttendanceResult(
      success: true,
      message: 'OK',
      data: AttendanceRecord(id: 42),
    );
  }
}

class _Scanner extends MobileScannerController {
  _Scanner() : super(autoStart: false);
  int starts = 0;
  int stops = 0;
  @override
  Future<void> start({
    CameraFacing? cameraDirection,
    CameraLensType? cameraLensType,
  }) async {
    starts++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  // Test controller deliberately avoids the platform disposal call.
  // ignore: must_call_super
  Future<void> dispose() async {}
}

void main() {
  late _Service service;
  late _Scanner scanner;
  late void Function(BarcodeCapture) detect;
  Future<void> mount(WidgetTester tester) async {
    service = _Service();
    scanner = _Scanner();
    await tester.pumpWidget(
      MaterialApp(
        home: BiometricQrScreen(
          attendanceService: service,
          scannerController: scanner,
          scannerBuilder: (context, controller, onDetect) {
            detect = onDetect;
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void scan() =>
      detect(const BarcodeCapture(barcodes: [Barcode(rawValue: ' QR_TOKEN ')]));
  testWidgets('requires action, submits once and stays disarmed after result', (
    tester,
  ) async {
    await mount(tester);
    scan();
    await tester.pump();
    expect(service.calls, isEmpty);
    expect(scanner.starts, 0);
    service.pending = Completer<AttendanceResult>();
    await tester.tap(find.text('Check-in'));
    await tester.pump();
    scan();
    scan();
    await tester.pump();
    expect(service.calls, ['in:QR:QR_TOKEN']);
    service.pending!.complete(
      AttendanceResult(success: false, message: 'Failure'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    scan();
    await tester.pump();
    expect(service.calls, hasLength(1));
    await tester.tap(find.text('Check-in'));
    await tester.pump();
    scan();
    await tester.pumpAndSettle();
    expect(service.calls, hasLength(2));
  });
  testWidgets('checkout opens mood dialog and stays locked until dismissed', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Check-out'));
    await tester.pump();
    scan();
    await tester.pumpAndSettle();
    expect(service.calls, ['out:QR:QR_TOKEN']);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay bạn cảm thấy thế nào?'), findsOneWidget);
    scan();
    expect(service.calls, hasLength(1));
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    scan();
    expect(service.calls, hasLength(1));
  });
  testWidgets('create tab and background disarm scanning', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Check-in'));
    await tester.pump();
    await tester.tap(find.text('Tạo mã QR'));
    await tester.pumpAndSettle();
    scan();
    expect(service.calls, isEmpty);
    expect(scanner.stops, greaterThan(0));
    await tester.tap(find.text('Quét mã QR'));
    await tester.pumpAndSettle();
    scan();
    expect(service.calls, isEmpty);
    await tester.tap(find.text('Check-in'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    scan();
    expect(service.calls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    scan();
    expect(service.calls, isEmpty);
  });
}
