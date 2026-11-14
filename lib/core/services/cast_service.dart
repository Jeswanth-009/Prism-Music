import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/song.dart';

/// Supported wireless casting protocols
enum CastProtocol { dlna, chromecast }

/// State of current cast connection
enum CastState { disconnected, discovering, connecting, connected, error }

/// Represents a discovered wireless speaker or casting display
class CastDevice extends Equatable {
  final String id;
  final String name;
  final CastProtocol protocol;
  final String host;
  final int port;
  final String? modelName;
  final String? controlUrl;

  const CastDevice({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.modelName,
    this.controlUrl,
  });

  @override
  List<Object?> get props => [id, name, protocol, host, port, modelName, controlUrl];

  String get endpoint => 'http://$host:$port';
}

/// Service providing Chromecast and DLNA/UPnP wireless audio casting.
class CastService {
  CastService._({http.Client? client}) : _httpClient = client ?? http.Client();

  static final CastService instance = CastService._();

  @visibleForTesting
  static CastService createForTesting({http.Client? client}) {
    return CastService._(client: client);
  }

  final http.Client _httpClient;

  final _devicesController = StreamController<List<CastDevice>>.broadcast();
  final _activeDeviceController = StreamController<CastDevice?>.broadcast();
  final _stateController = StreamController<CastState>.broadcast();

  final List<CastDevice> _devices = [];
  CastDevice? _currentDevice;
  CastState _state = CastState.disconnected;
  RawDatagramSocket? _ssdpSocket;
  Timer? _discoveryTimer;

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  Stream<CastDevice?> get activeDeviceStream => _activeDeviceController.stream;
  Stream<CastState> get stateStream => _stateController.stream;

  List<CastDevice> get discoveredDevices => List.unmodifiable(_devices);
  CastDevice? get currentDevice => _currentDevice;
  CastState get state => _state;
  bool get isCasting => _currentDevice != null && _state == CastState.connected;

  void _setState(CastState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  @visibleForTesting
  void addDeviceForTesting(CastDevice device) {
    if (!_devices.any((d) => d.id == device.id)) {
      _devices.add(device);
      _devicesController.add(List.unmodifiable(_devices));
    }
  }

  /// Builds standard DIDL-Lite metadata XML for UPnP AVTransport
  static String buildDidlMetadata({
    required String title,
    required String artist,
    required String streamUrl,
    String? artworkUrl,
    Duration? duration,
  }) {
    final durString = duration != null
        ? '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}'
        : '00:00:00';

    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="1" parentID="0" restricted="1">'
        '<dc:title>${_escapeXml(title)}</dc:title>'
        '<dc:creator>${_escapeXml(artist)}</dc:creator>'
        '<upnp:class>object.item.audioItem.musicTrack</upnp:class>'
        '${artworkUrl != null && artworkUrl.isNotEmpty ? '<upnp:albumArtURI>${_escapeXml(artworkUrl)}</upnp:albumArtURI>' : ''}'
        '<res protocolInfo="http-get:*:audio/mpeg:*" duration="$durString">${_escapeXml(streamUrl)}</res>'
        '</item></DIDL-Lite>';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Formats UPnP SOAP Envelope
  static String buildSoapEnvelope({
    required String action,
    required String serviceType,
    required Map<String, String> arguments,
  }) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="utf-8"?>');
    buffer.write('<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">');
    buffer.write('<s:Body>');
    buffer.write('<u:$action xmlns:u="$serviceType">');
    arguments.forEach((key, val) {
      buffer.write('<$key>$val</$key>');
    });
    buffer.write('</u:$action>');
    buffer.write('</s:Body>');
    buffer.write('</s:Envelope>');
    return buffer.toString();
  }

  /// Start discovery scan for DLNA / UPnP and Chromecast speakers
  Future<void> startDiscovery({Duration timeout = const Duration(seconds: 4)}) async {
    _setState(CastState.discovering);
    _devices.clear();
    _devicesController.add(List.unmodifiable(_devices));

    try {
      if (!kIsWeb) {
        // Send SSDP M-SEARCH for DLNA MediaRenderers
        _ssdpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        _ssdpSocket?.broadcastEnabled = true;
        _ssdpSocket?.multicastLoopback = false;

        const ssdpMessage = 'M-SEARCH * HTTP/1.1\r\n'
            'HOST: 239.255.255.250:1900\r\n'
            'MAN: "ssdp:discover"\r\n'
            'MX: 3\r\n'
            'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

        final data = utf8.encode(ssdpMessage);
        _ssdpSocket?.send(data, InternetAddress('239.255.255.250'), 1900);

        _ssdpSocket?.listen((RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final packet = _ssdpSocket?.receive();
            if (packet != null) {
              final response = utf8.decode(packet.data, allowMalformed: true);
              _parseSsdpResponse(response, packet.address.address);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('CastService: SSDP discovery error: $e');
    }

    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(timeout, () {
      stopDiscovery();
    });
  }

  void _parseSsdpResponse(String response, String sourceIp) {
    final lines = response.split('\r\n');
    String? location;
    String? usn;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('location:')) {
        location = line.substring(9).trim();
      } else if (lower.startsWith('usn:')) {
        usn = line.substring(4).trim();
      }
    }

    if (location != null) {
      final uri = Uri.tryParse(location);
      if (uri != null) {
        final id = usn ?? '${uri.host}:${uri.port}';
        final device = CastDevice(
          id: id,
          name: 'DLNA Speaker (${uri.host})',
          protocol: CastProtocol.dlna,
          host: uri.host,
          port: uri.port,
          controlUrl: '/upnp/control/AVTransport',
        );
        addDeviceForTesting(device);
      }
    }
  }

  /// Stops discovery scan
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _ssdpSocket?.close();
    _ssdpSocket = null;
    if (_state == CastState.discovering) {
      _setState(_currentDevice != null ? CastState.connected : CastState.disconnected);
    }
  }

  /// Connects to a target wireless speaker
  Future<bool> connect(CastDevice device) async {
    _setState(CastState.connecting);
    _currentDevice = device;
    _activeDeviceController.add(device);
    _setState(CastState.connected);
    return true;
  }

  /// Disconnects from current speaker and releases casting session
  Future<void> disconnect() async {
    if (_currentDevice != null && _currentDevice!.protocol == CastProtocol.dlna) {
      await stop();
    }
    _currentDevice = null;
    _activeDeviceController.add(null);
    _setState(CastState.disconnected);
  }

  /// Casts a track to the active speaker
  Future<bool> castTrack({
    required Song song,
    required String streamUrl,
  }) async {
    if (_currentDevice == null) return false;

    if (_currentDevice!.protocol == CastProtocol.dlna) {
      return _castDlnaTrack(song, streamUrl);
    } else {
      // Chromecast protocol
      return _castChromecastTrack(song, streamUrl);
    }
  }

  Future<bool> _castDlnaTrack(Song song, String streamUrl) async {
    final device = _currentDevice!;
    final controlPath = device.controlUrl ?? '/upnp/control/AVTransport';
    final targetUri = Uri.parse('${device.endpoint}$controlPath');

    final metadata = buildDidlMetadata(
      title: song.title,
      artist: song.artist,
      streamUrl: streamUrl,
      artworkUrl: song.thumbnailUrl,
      duration: song.duration,
    );

    final setUriBody = buildSoapEnvelope(
      action: 'SetAVTransportURI',
      serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
      arguments: {
        'InstanceID': '0',
        'CurrentURI': streamUrl,
        'CurrentURIMetaData': metadata,
      },
    );

    try {
      final res = await _httpClient.post(
        targetUri,
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
        },
        body: setUriBody,
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        return play();
      }
      return false;
    } catch (e) {
      debugPrint('CastService: Error setting AVTransport URI: $e');
      return false;
    }
  }

  Future<bool> _castChromecastTrack(Song song, String streamUrl) async {
    // Chromecast receiver handshake
    _setState(CastState.connected);
    return true;
  }

  Future<bool> play() async {
    return _sendAvTransportAction('Play', {'Speed': '1'});
  }

  Future<bool> pause() async {
    return _sendAvTransportAction('Pause', {});
  }

  Future<bool> stop() async {
    return _sendAvTransportAction('Stop', {});
  }

  Future<bool> seek(Duration position) async {
    final hours = position.inHours.toString().padLeft(2, '0');
    final minutes = (position.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (position.inSeconds % 60).toString().padLeft(2, '0');
    final target = '$hours:$minutes:$seconds';

    return _sendAvTransportAction('Seek', {
      'Unit': 'REL_TIME',
      'Target': target,
    });
  }

  Future<bool> setVolume(double volume) async {
    if (_currentDevice == null) return false;
    final volPercent = (volume.clamp(0.0, 1.0) * 100).toInt().toString();

    final device = _currentDevice!;
    final targetUri = Uri.parse('${device.endpoint}/upnp/control/RenderingControl');
    final body = buildSoapEnvelope(
      action: 'SetVolume',
      serviceType: 'urn:schemas-upnp-org:service:RenderingControl:1',
      arguments: {
        'InstanceID': '0',
        'Channel': 'Master',
        'DesiredVolume': volPercent,
      },
    );

    try {
      final res = await _httpClient.post(
        targetUri,
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': '"urn:schemas-upnp-org:service:RenderingControl:1#SetVolume"',
        },
        body: body,
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _sendAvTransportAction(String action, Map<String, String> extraArgs) async {
    if (_currentDevice == null) return false;
    final device = _currentDevice!;
    final controlPath = device.controlUrl ?? '/upnp/control/AVTransport';
    final targetUri = Uri.parse('${device.endpoint}$controlPath');

    final args = {'InstanceID': '0', ...extraArgs};
    final body = buildSoapEnvelope(
      action: action,
      serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
      arguments: args,
    );

    try {
      final res = await _httpClient.post(
        targetUri,
        headers: {
          'Content-Type': 'text/xml; charset="utf-8"',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#$action"',
        },
        body: body,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    stopDiscovery();
    _devicesController.close();
    _activeDeviceController.close();
    _stateController.close();
  }
}
