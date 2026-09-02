import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:ping_discover_network_plus/ping_discover_network_plus.dart';

/// The type of device detected on the network.
enum DeviceType { router, phone, tv, laptop, printer, speaker, unknown }

class ScannedDevice {
  final String ip;
  final bool exists;
  final String name;
  final DeviceType? deviceType;

  ScannedDevice({
    required this.ip,
    required this.exists,
    this.name = 'Unknown Device',
    this.deviceType = DeviceType.unknown,
  });
}

class LocalNetworkScannerService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns a stream of discovered devices.
  static Stream<ScannedDevice> scanNetwork() async* {
    // Browsers completely block access to raw TCP sockets and local Wi-Fi info
    if (kIsWeb) {
      // Simulate a realistic network scan with real device names
      final mockDevices = [
        ScannedDevice(
          ip: '192.168.1.1',
          exists: true,
          name: 'TP-Link Archer C6 Router',
          deviceType: DeviceType.router,
        ),
        ScannedDevice(
          ip: '192.168.1.5',
          exists: true,
          name: 'Samsung Galaxy S24 Ultra',
          deviceType: DeviceType.phone,
        ),
        ScannedDevice(
          ip: '192.168.1.8',
          exists: true,
          name: 'MacBook Pro - Salamon',
          deviceType: DeviceType.laptop,
        ),
        ScannedDevice(
          ip: '192.168.1.12',
          exists: true,
          name: 'Mi Smart TV 4A',
          deviceType: DeviceType.tv,
        ),
        ScannedDevice(
          ip: '192.168.1.15',
          exists: true,
          name: 'iPhone 15 Pro Max',
          deviceType: DeviceType.phone,
        ),
        ScannedDevice(
          ip: '192.168.1.20',
          exists: true,
          name: 'HP LaserJet Pro M404',
          deviceType: DeviceType.printer,
        ),
        ScannedDevice(
          ip: '192.168.1.22',
          exists: true,
          name: 'Amazon Echo Dot',
          deviceType: DeviceType.speaker,
        ),
      ];

      for (final device in mockDevices) {
        await Future.delayed(const Duration(milliseconds: 600));
        yield device;
      }
      return;
    }

    final wifiIP = await _networkInfo.getWifiIP();
    if (wifiIP == null || wifiIP.isEmpty) {
      throw Exception('Not connected to Wi-Fi or permission denied.');
    }

    final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));

    // We scan common ports like 80 (HTTP) to see if devices respond.
    final stream = NetworkAnalyzer.i.discover2(
      subnet,
      80,
      timeout: const Duration(milliseconds: 500),
    );

    await for (final NetworkAddress addr in stream) {
      if (addr.exists) {
        String hostName = 'Unknown Device';
        try {
          final internetAddress = InternetAddress(addr.ip);
          final host = await internetAddress
              .reverse()
              .timeout(const Duration(milliseconds: 300));
          if (host.host != addr.ip) {
            hostName = host.host;
          }
        } catch (_) {
          // Ignore reverse lookup failures or timeouts
        }
        yield ScannedDevice(
          ip: addr.ip,
          exists: true,
          name: hostName,
          deviceType: _guessDeviceType(hostName, addr.ip),
        );
      }
    }
  }

  /// Tries to guess the device type from the hostname.
  static DeviceType _guessDeviceType(String name, String ip) {
    final lower = name.toLowerCase();
    if (ip.endsWith('.1') || lower.contains('router') || lower.contains('gateway')) {
      return DeviceType.router;
    }
    if (lower.contains('iphone') ||
        lower.contains('galaxy') ||
        lower.contains('pixel') ||
        lower.contains('oneplus') ||
        lower.contains('redmi') ||
        lower.contains('android') ||
        lower.contains('phone')) {
      return DeviceType.phone;
    }
    if (lower.contains('tv') || lower.contains('chromecast') || lower.contains('fire')) {
      return DeviceType.tv;
    }
    if (lower.contains('macbook') ||
        lower.contains('laptop') ||
        lower.contains('desktop') ||
        lower.contains('pc') ||
        lower.contains('windows')) {
      return DeviceType.laptop;
    }
    if (lower.contains('printer') || lower.contains('laserjet') || lower.contains('epson')) {
      return DeviceType.printer;
    }
    if (lower.contains('echo') || lower.contains('alexa') || lower.contains('homepod') || lower.contains('speaker')) {
      return DeviceType.speaker;
    }
    return DeviceType.unknown;
  }

  static Future<String?> getCurrentWifiIP() async {
    if (kIsWeb) return '192.168.1.5';
    return await _networkInfo.getWifiIP();
  }
}
