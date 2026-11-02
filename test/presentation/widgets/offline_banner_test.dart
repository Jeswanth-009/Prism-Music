import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_music/core/services/offline_mode_service.dart';
import 'package:prism_music/core/services/settings_service.dart';
import 'package:prism_music/presentation/widgets/common/offline_banner.dart';

class MockConnectivity extends Mock implements Connectivity {}
class MockSettingsService extends Mock implements SettingsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockConnectivity mockConnectivity;
  late MockSettingsService mockSettings;
  late StreamController<List<ConnectivityResult>> connectivityController;
  late OfflineModeService offlineService;

  setUp(() {
    mockConnectivity = MockConnectivity();
    mockSettings = MockSettingsService();
    connectivityController = StreamController<List<ConnectivityResult>>.broadcast();

    when(() => mockSettings.forceOfflineMode).thenReturn(false);
    when(() => mockSettings.setForceOfflineMode(any())).thenAnswer((_) async {});
    when(() => mockConnectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityController.stream);
    when(() => mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    offlineService = OfflineModeService(
      connectivity: mockConnectivity,
      settingsService: mockSettings,
    );
  });

  tearDown(() {
    connectivityController.close();
  });

  Widget buildWidget({VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: OfflineBanner(
          offlineModeService: offlineService,
          onTap: onTap,
        ),
      ),
    );
  }

  group('OfflineBanner Widget', () {
    testWidgets('renders empty/collapsed when app is online', (tester) async {
      await offlineService.initialize();
      await tester.pumpWidget(buildWidget());

      expect(find.text('Offline Mode • Playing downloaded tracks'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
    });

    testWidgets('animates and renders banner when transitioned to offline', (tester) async {
      await offlineService.initialize();
      await tester.pumpWidget(buildWidget());
      expect(find.text('Offline Mode • Playing downloaded tracks'), findsNothing);

      // Trigger offline network state
      connectivityController.add([ConnectivityResult.none]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Offline Mode • Playing downloaded tracks'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped while offline', (tester) async {
      await offlineService.initialize();
      bool tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

      await offlineService.setForceOffline(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(OfflineBanner));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
