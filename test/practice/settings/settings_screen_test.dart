import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/preferences_store.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/settings_provider.dart';
import 'package:Nhom_3_nguoi/practice/features/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'preferences_test_support.dart';

Future<SettingsProvider> settings() async => SettingsProvider(
  store: PreferencesStore(await SharedPreferences.getInstance()),
);

Widget host(SettingsProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: Builder(
    builder: (context) => MaterialApp(
      theme: ThemeData(
        brightness: context.watch<SettingsProvider>().darkMode
            ? Brightness.dark
            : Brightness.light,
      ),
      home: const Scaffold(body: SettingsScreen()),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'invalid endpoint stays in the form and does not replace saved URL',
    (tester) async {
      final provider = await settings();
      await tester.pumpWidget(host(provider));
      await tester.enterText(
        find.byType(TextFormField),
        'http://example.org/posts',
      );
      await tester.tap(find.text('Lưu địa chỉ API'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nhập URL HTTPS'), findsOneWidget);
      expect(provider.endpoint, SettingsProvider.defaultEndpoint);
    },
  );

  testWidgets('theme rebuild keeps unsaved endpoint edits', (tester) async {
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    await tester.enterText(
      find.byType(TextFormField),
      'https://draft.example/posts',
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(provider.darkMode, isTrue);
    expect(find.text('https://draft.example/posts'), findsOneWidget);
    expect(provider.endpoint, SettingsProvider.defaultEndpoint);
  });

  testWidgets('saving a valid endpoint persists and confirms success', (
    tester,
  ) async {
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    await tester.enterText(
      find.byType(TextFormField),
      'https://server.example/api/posts',
    );
    await tester.tap(find.text('Lưu địa chỉ API'));
    await tester.pumpAndSettle();
    expect(provider.endpoint, 'https://server.example/api/posts');
    expect(find.text('Đã lưu địa chỉ API.'), findsOneWidget);
    SharedPreferences.resetStatic();
    expect((await settings()).endpoint, 'https://server.example/api/posts');
  });

  testWidgets('default endpoint button changes draft before explicit save', (
    tester,
  ) async {
    final provider = await settings();
    await provider.setEndpoint('https://custom.example/api/posts');
    await tester.pumpWidget(host(provider));
    await tester.tap(find.text('Dùng địa chỉ mặc định'));
    await tester.pumpAndSettle();
    expect(find.text(SettingsProvider.defaultEndpoint), findsOneWidget);
    expect(provider.endpoint, 'https://custom.example/api/posts');
    await tester.tap(find.text('Lưu địa chỉ API'));
    await tester.pumpAndSettle();
    expect(provider.endpoint, SettingsProvider.defaultEndpoint);
  });

  testWidgets('failed theme save keeps switch at confirmed value', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    final platform = ControlledPreferencesPlatform();
    SharedPreferencesStorePlatform.instance = platform;
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    platform.failNextWrite = true;
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể lưu dữ liệu'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(provider.darkMode, isFalse);
  });

  testWidgets('write failure surfaces SnackBar and preserves endpoint draft', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    final platform = ControlledPreferencesPlatform();
    SharedPreferencesStorePlatform.instance = platform;
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    await tester.enterText(
      find.byType(TextFormField),
      'https://draft.example/posts',
    );
    platform.failNextWrite = true;
    await tester.tap(find.text('Lưu địa chỉ API'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không thể lưu dữ liệu'), findsOneWidget);
    expect(find.text('https://draft.example/posts'), findsOneWidget);
    expect(provider.endpoint, SettingsProvider.defaultEndpoint);
  });

  testWidgets('pending save disables duplicate actions and survives unmount', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    final platform = ControlledPreferencesPlatform();
    SharedPreferencesStorePlatform.instance = platform;
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    await tester.enterText(
      find.byType(TextFormField),
      'https://slow.example/posts',
    );
    final gate = Completer<void>();
    platform.gate = gate;
    await tester.tap(find.text('Lưu địa chỉ API'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(provider.endpoint, 'https://slow.example/posts');
  });

  testWidgets(
    'narrow screen with large text remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = await settings();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: const Scaffold(body: SettingsScreen()),
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Lưu địa chỉ API'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('emulator preset saves the real local backend endpoint', (tester) async {
    final provider = await settings();
    await tester.pumpWidget(host(provider));
    final preset = find.text('Backend máy ảo');
    expect(preset, findsOneWidget);
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.pumpAndSettle();
    expect(provider.endpoint, 'http://10.0.2.2:5186/api/posts');
    expect(find.text('Đã lưu địa chỉ API.'), findsOneWidget);
  });
}
