import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prism_music/core/services/cast_service.dart';
import 'package:prism_music/domain/entities/song.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastService', () {
    test('buildDidlMetadata formats valid UPnP XML with title and artist', () {
      final xml = CastService.buildDidlMetadata(
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        streamUrl: 'https://example.com/stream.mp3',
        artworkUrl: 'https://example.com/cover.jpg',
        duration: const Duration(minutes: 5, seconds: 55),
      );

      expect(xml, contains('<dc:title>Bohemian Rhapsody</dc:title>'));
      expect(xml, contains('<dc:creator>Queen</dc:creator>'));
      expect(xml, contains('<res protocolInfo="http-get:*:audio/mpeg:*" duration="00:05:55">'));
      expect(xml, contains('<upnp:albumArtURI>https://example.com/cover.jpg</upnp:albumArtURI>'));
    });

    test('buildSoapEnvelope builds standard SOAP body with action arguments', () {
      final soap = CastService.buildSoapEnvelope(
        action: 'Play',
        serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
        arguments: {'InstanceID': '0', 'Speed': '1'},
      );

      expect(soap, contains('<s:Envelope'));
      expect(soap, contains('<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">'));
      expect(soap, contains('<InstanceID>0</InstanceID>'));
      expect(soap, contains('<Speed>1</Speed>'));
      expect(soap, contains('</u:Play>'));
    });

    test('connects and disconnects from device correctly', () async {
      final service = CastService.createForTesting();

      const device = CastDevice(
        id: 'dev_1',
        name: 'Living Room Sonos',
        protocol: CastProtocol.dlna,
        host: '192.168.1.150',
        port: 1400,
      );

      expect(device.endpoint, equals('http://192.168.1.150:1400'));
      expect(service.state, equals(CastState.disconnected));

      final connected = await service.connect(device);
      expect(connected, isTrue);
      expect(service.state, equals(CastState.connected));
      expect(service.currentDevice, equals(device));
      expect(service.isCasting, isTrue);

      await service.disconnect();
      expect(service.state, equals(CastState.disconnected));
      expect(service.currentDevice, isNull);
      expect(service.isCasting, isFalse);
    });

    test('castTrack dispatches SOAP AVTransport SetAVTransportURI request', () async {
      var postedSetUri = false;
      var postedPlay = false;

      final mockClient = MockClient((request) async {
        final body = request.body;
        if (body.contains('SetAVTransportURI')) {
          postedSetUri = true;
          return http.Response('<s:Envelope></s:Envelope>', 200);
        }
        if (body.contains('<u:Play')) {
          postedPlay = true;
          return http.Response('<s:Envelope></s:Envelope>', 200);
        }
        return http.Response('', 200);
      });

      final service = CastService.createForTesting(client: mockClient);
      const device = CastDevice(
        id: 'dev_2',
        name: 'Den Smart Speaker',
        protocol: CastProtocol.dlna,
        host: '192.168.1.180',
        port: 8080,
      );

      await service.connect(device);

      const song = Song(
        id: 's_queen',
        title: 'Don\'t Stop Me Now',
        artist: 'Queen',
        thumbnails: Thumbnails(),
        duration: Duration(minutes: 3, seconds: 29),
      );

      final result = await service.castTrack(
        song: song,
        streamUrl: 'https://cdn.example.com/music.mp3',
      );

      expect(result, isTrue);
      expect(postedSetUri, isTrue);
      expect(postedPlay, isTrue);
    });
  });
}
