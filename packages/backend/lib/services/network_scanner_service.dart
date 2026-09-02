import 'dart:io';

/// Service that performs real network scanning on the server machine.
class NetworkScannerService {
  /// Common MAC OUI prefixes → manufacturer names
  static const Map<String, String> _ouiMap = {
    '00:1A:2B': 'Ayecom Technology',
    'AA:BB:CC': 'Unknown Vendor',
    // Apple
    '00:CD:FE': 'Apple', '3C:22:FB': 'Apple', 'A4:83:E7': 'Apple',
    'F0:18:98': 'Apple', '8C:85:90': 'Apple', 'AC:BC:32': 'Apple',
    '00:17:F2': 'Apple', '14:99:E2': 'Apple', '88:66:A5': 'Apple',
    'DC:A4:CA': 'Apple', '70:56:81': 'Apple',
    // Samsung
    '00:1E:E2': 'Samsung', '84:25:DB': 'Samsung', 'A8:7C:01': 'Samsung',
    '00:26:37': 'Samsung', 'C4:73:1E': 'Samsung', '50:01:BB': 'Samsung',
    '34:23:BA': 'Samsung', '78:BD:BC': 'Samsung', 'B4:3A:28': 'Samsung',
    // Xiaomi / Redmi
    '28:6C:07': 'Xiaomi', '64:CC:2E': 'Xiaomi', '00:9E:C8': 'Xiaomi',
    '78:11:DC': 'Xiaomi', '7C:1C:4E': 'Xiaomi', 'AC:C1:EE': 'Xiaomi',
    // OnePlus / Oppo / Realme (BBK)
    '94:65:2D': 'OnePlus', 'C0:EE:40': 'OnePlus',
    // Google
    'F4:F5:D8': 'Google', '54:60:09': 'Google', '3C:5A:B4': 'Google',
    // TP-Link
    '50:C7:BF': 'TP-Link', 'C0:06:C3': 'TP-Link', '60:32:B1': 'TP-Link',
    'E8:48:B8': 'TP-Link', '14:CC:20': 'TP-Link', 'B0:BE:76': 'TP-Link',
    // D-Link
    '1C:7E:E5': 'D-Link', '00:1E:58': 'D-Link', 'B8:A3:86': 'D-Link',
    // Netgear
    '00:14:6C': 'Netgear', 'C4:04:15': 'Netgear', '20:E5:2A': 'Netgear',
    // Intel
    '00:1B:21': 'Intel', '68:05:CA': 'Intel', '3C:F0:11': 'Intel',
    'A0:36:9F': 'Intel', '8C:EC:4B': 'Intel',
    // Realtek (USB Wi-Fi adapters, etc)
    '00:E0:4C': 'Realtek', '52:54:00': 'Realtek',
    // HP
    '00:1A:4B': 'HP', '3C:D9:2B': 'HP', '00:25:B3': 'HP',
    // Dell
    '00:14:22': 'Dell', 'F8:DB:88': 'Dell',
    // Lenovo
    '00:06:1B': 'Lenovo', '98:FA:9B': 'Lenovo',
    // Microsoft (Surface, Xbox)
    '7C:1E:52': 'Microsoft', '28:18:78': 'Microsoft',
    // Amazon
    '40:B4:CD': 'Amazon', 'F0:F0:A4': 'Amazon', '44:65:0D': 'Amazon',
    // Huawei / Honor
    '00:E0:FC': 'Huawei', '48:46:FB': 'Huawei', 'CC:A2:23': 'Huawei',
    '70:8C:B6': 'Huawei', '24:09:95': 'Huawei',
    // LG
    '00:1E:75': 'LG', 'A8:23:FE': 'LG',
    // Sony
    'FC:F1:52': 'Sony', '00:04:1F': 'Sony',
    // Roku
    'DC:3A:5E': 'Roku', 'B0:A7:37': 'Roku',
    // Vizio
    '00:19:9D': 'Vizio',
    // Asus
    '00:1A:92': 'Asus', '04:D9:F5': 'Asus', 'AC:9E:17': 'Asus',
    '1C:87:2C': 'Asus', '2C:FD:A1': 'Asus',
    // Raspberry Pi
    'B8:27:EB': 'Raspberry Pi', 'DC:A6:32': 'Raspberry Pi',
    'E4:5F:01': 'Raspberry Pi',
    // Espressif (ESP8266/ESP32 IoT devices)
    '24:0A:C4': 'Espressif IoT', '30:AE:A4': 'Espressif IoT',
  };

  /// Scans the local network using the system's ARP table.
  /// Returns a list of discovered devices with IP, MAC, and resolved name.
  static Future<List<Map<String, String>>> scanNetwork() async {
    final devices = <Map<String, String>>[];

    try {
      // Run arp -a to get the ARP table
      final result = await Process.run('arp', ['-a']);
      final output = result.stdout.toString();

      // Parse each line of arp output (Windows format)
      // Format: "  192.168.1.1          aa-bb-cc-dd-ee-ff     dynamic"
      final regex = RegExp(
        r'(\d+\.\d+\.\d+\.\d+)\s+([\da-fA-F]{2}-[\da-fA-F]{2}-[\da-fA-F]{2}-[\da-fA-F]{2}-[\da-fA-F]{2}-[\da-fA-F]{2})\s+(\w+)',
      );

      for (final match in regex.allMatches(output)) {
        final ip = match.group(1)!;
        // Convert Windows MAC format (aa-bb-cc-dd-ee-ff) to standard (AA:BB:CC:DD:EE:FF)
        final mac = match.group(2)!.replaceAll('-', ':').toUpperCase();
        final type = match.group(3)!; // "dynamic" or "static"

        // Skip broadcast/multicast addresses
        if (mac == 'FF:FF:FF:FF:FF:FF') continue;
        if (ip.endsWith('.255')) continue;

        // Try to resolve the hostname
        String deviceName = _getManufacturer(mac);
        String deviceType = 'unknown';

        try {
          final hostEntry = await InternetAddress(ip)
              .reverse()
              .timeout(const Duration(milliseconds: 500));
          if (hostEntry.host != ip) {
            deviceName = hostEntry.host;
          }
        } catch (_) {
          // Reverse DNS failed, use manufacturer name
        }

        // Guess device type from manufacturer + hostname
        deviceType = _guessDeviceType(deviceName, mac, ip);

        // If name is still just manufacturer, enhance it
        if (deviceName == _getManufacturer(mac)) {
          deviceName = '$deviceName Device';
          if (ip.endsWith('.1')) {
            deviceName = '${ _getManufacturer(mac)} Router';
            deviceType = 'router';
          }
        }

        devices.add({
          'ip_address': ip,
          'mac_address': mac,
          'device_name': deviceName,
          'device_type': deviceType,
          'status': 'online',
          'arp_type': type,
        });
      }
    } catch (e) {
      print('Network scan error: $e');
    }

    return devices;
  }

  /// Look up manufacturer from the first 3 octets of the MAC address (OUI).
  static String _getManufacturer(String mac) {
    final oui = mac.substring(0, 8); // "AA:BB:CC"
    return _ouiMap[oui] ?? 'Unknown';
  }

  /// Guess device type from name, manufacturer, and IP patterns.
  static String _guessDeviceType(String name, String mac, String ip) {
    final lower = name.toLowerCase();
    final manufacturer = _getManufacturer(mac).toLowerCase();

    // Router detection
    if (ip.endsWith('.1') || lower.contains('router') || lower.contains('gateway')) {
      return 'router';
    }
    // Known router manufacturers for .1 IPs
    if (['tp-link', 'd-link', 'netgear', 'asus'].contains(manufacturer) && ip.endsWith('.1')) {
      return 'router';
    }
    // Phone detection
    if (lower.contains('iphone') || lower.contains('android') || lower.contains('galaxy') ||
        lower.contains('pixel') || lower.contains('oneplus') || lower.contains('redmi')) {
      return 'smartphone';
    }
    if (['samsung', 'xiaomi', 'oneplus', 'huawei', 'google'].contains(manufacturer)) {
      return 'smartphone';
    }
    if (manufacturer == 'apple' && !lower.contains('macbook') && !lower.contains('imac') && !lower.contains('tv')) {
      return 'smartphone'; // Default Apple to iPhone
    }
    // TV detection
    if (lower.contains('tv') || lower.contains('roku') || lower.contains('chromecast') || lower.contains('fire')) {
      return 'tv';
    }
    if (['lg', 'sony', 'vizio', 'roku', 'amazon'].contains(manufacturer)) {
      return 'tv';
    }
    // Laptop/Desktop detection
    if (lower.contains('macbook') || lower.contains('laptop') || lower.contains('desktop') ||
        lower.contains('pc') || lower.contains('surface')) {
      return 'laptop';
    }
    if (['dell', 'lenovo', 'microsoft', 'intel'].contains(manufacturer)) {
      return 'laptop';
    }
    // Printer
    if (lower.contains('printer') || manufacturer == 'hp') {
      return 'printer';
    }
    // Smart speaker
    if (lower.contains('echo') || lower.contains('alexa') || lower.contains('homepod')) {
      return 'speaker';
    }
    // IoT
    if (manufacturer.contains('espressif') || manufacturer.contains('raspberry')) {
      return 'iot';
    }
    return 'unknown';
  }
}
