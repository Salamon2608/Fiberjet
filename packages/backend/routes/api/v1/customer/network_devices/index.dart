import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/network_scanner_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/customer/network_devices       → List devices from DB
/// POST /api/v1/customer/network_devices       → Trigger a real-time network scan
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Return saved devices from database ──────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT * FROM connected_devices WHERE user_id = @userId ORDER BY last_seen DESC',
      substitutionValues: {'userId': user.id},
    );

    // If no devices exist, trigger an initial scan
    if (result.isEmpty) {
      return _scanAndSave(db, user);
    }

    final devices = result.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'device_name': map['device_name'],
        'mac_address': map['mac_address'],
        'ip_address': map['ip_address'],
        'device_type': map['device_type'],
        'status': map['status'],
        'access_level': map['access_level'],
        'last_seen': map['last_seen']?.toString(),
      };
    }).toList();

    return ApiResponse.success(data: devices);
  }

  // ── POST: Trigger a real-time network scan ───────────────────
  if (request.method == HttpMethod.post) {
    return _scanAndSave(db, user);
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}

/// Runs a real network scan, upserts devices into DB, and returns the list.
Future<Response> _scanAndSave(PostgresService db, UserModel user) async {
  try {
    print('Starting real-time network scan for user: ${user.id}');
    final scannedDevices = await NetworkScannerService.scanNetwork();
    print('Scan complete. Found ${scannedDevices.length} devices.');

    final savedDevices = <Map<String, dynamic>>[];

    for (final device in scannedDevices) {
      final mac = device['mac_address']!;
      final ip = device['ip_address']!;
      final name = device['device_name']!;
      final type = device['device_type']!;

      // Upsert: update if MAC exists for this user, otherwise insert
      final existing = await db.query(
        'SELECT id, access_level FROM connected_devices WHERE user_id = @userId AND mac_address = @mac',
        substitutionValues: {'userId': user.id, 'mac': mac},
      );

      if (existing.isNotEmpty) {
        // Update existing device (keep access_level)
        final row = existing.first.toColumnMap();
        await db.query(
          '''UPDATE connected_devices
             SET ip_address = @ip, device_name = @name, device_type = @type,
                 status = 'online', last_seen = NOW()
             WHERE id = @id''',
          substitutionValues: {
            'id': row['id'],
            'ip': ip,
            'name': name,
            'type': type,
          },
        );
        savedDevices.add({
          'id': row['id'],
          'device_name': name,
          'mac_address': mac,
          'ip_address': ip,
          'device_type': type,
          'status': 'online',
          'access_level': row['access_level'],
          'last_seen': DateTime.now().toIso8601String(),
        });
      } else {
        // Insert new device
        final insertResult = await db.query(
          '''INSERT INTO connected_devices (user_id, device_name, mac_address, ip_address, device_type, status, access_level)
             VALUES (@userId, @name, @mac, @ip, @type, 'online', 'trusted')
             RETURNING *''',
          substitutionValues: {
            'userId': user.id,
            'name': name,
            'mac': mac,
            'ip': ip,
            'type': type,
          },
        );
        if (insertResult.isNotEmpty) {
          final map = insertResult.first.toColumnMap();
          savedDevices.add({
            'id': map['id'],
            'device_name': map['device_name'],
            'mac_address': map['mac_address'],
            'ip_address': map['ip_address'],
            'device_type': map['device_type'],
            'status': map['status'],
            'access_level': map['access_level'],
            'last_seen': map['last_seen']?.toString(),
          });
        }
      }
    }

    // Mark devices NOT in current scan as offline
    final scannedMacs = scannedDevices.map((d) => d['mac_address']).toList();
    if (scannedMacs.isNotEmpty) {
      await db.query(
        '''UPDATE connected_devices SET status = 'offline'
           WHERE user_id = @userId AND mac_address != ALL(@macs)''',
        substitutionValues: {'userId': user.id, 'macs': scannedMacs},
      );
    }

    return ApiResponse.success(data: savedDevices);
  } catch (e) {
    print('Network scan error: $e');
    return ApiResponse.error(message: 'Scan failed: $e');
  }
}
