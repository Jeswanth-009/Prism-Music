import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/cast_service.dart';
import 'package:prism_music/presentation/widgets/dialogs/cast_device_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastDevicePickerDialog', () {
    testWidgets('renders device list and connects when tapped', (tester) async {
      final cast = CastService.instance;
      await cast.disconnect();

      const device = CastDevice(
        id: 'test_speaker_1',
        name: 'Office Audio Receiver',
        protocol: CastProtocol.dlna,
        host: '192.168.1.120',
        port: 49152,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CastDevicePickerDialog(),
          ),
        ),
      );

      // Add device to active discovery stream
      cast.addDeviceForTesting(device);
      await tester.pumpAndSettle();

      expect(find.text('Cast to Speaker'), findsOneWidget);
      expect(find.text('Office Audio Receiver'), findsOneWidget);
      expect(find.text('DLNA · 192.168.1.120'), findsOneWidget);

      await tester.tap(find.text('Office Audio Receiver'));
      await tester.pumpAndSettle();

      expect(cast.currentDevice, equals(device));
      expect(cast.isCasting, isTrue);

      await cast.disconnect();
    });
  });
}
