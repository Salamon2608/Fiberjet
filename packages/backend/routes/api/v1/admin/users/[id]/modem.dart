import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/admin/users/[id]/modem → Link or update a modem for a user
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  
  if (request.method != HttpMethod.post && request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT * FROM modem_info WHERE user_id = @userId LIMIT 1',
      substitutionValues: {'userId': id},
    );
    
    if (result.isEmpty) return ApiResponse.success(data: null);
    
    final modemData = result.first.toColumnMap();
    final sanitizedData = <String, dynamic>{};
    for (final key in modemData.keys) {
      final val = modemData[key];
      if (val is DateTime) sanitizedData[key] = val.toIso8601String();
      else sanitizedData[key] = val;
    }
    return ApiResponse.success(data: sanitizedData);
  }

  // 1. Check if user exists
  final userCheck = await db.query(
    'SELECT id FROM users WHERE id = @id LIMIT 1',
    substitutionValues: {'id': id},
  );

  if (userCheck.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  try {
    final body = await request.json() as Map<String, dynamic>;
    final macAddress = body['mac_address'] as String?;
    final deviceType = body['device_type'] as String? ?? 'Unknown';
    final ipAddress = body['ip_address'] as String? ?? '0.0.0.0';

    if (macAddress == null || macAddress.trim().isEmpty) {
      return ApiResponse.error(message: 'MAC address is required');
    }

    // Default values for a newly provisioned modem
    final defaultSignalStrength = -25; // Good signal
    
    // 2. Check if user already has a modem linked
    final modemCheck = await db.query(
      'SELECT id FROM modem_info WHERE user_id = @userId LIMIT 1',
      substitutionValues: {'userId': id},
    );

    Map<String, dynamic> modemData;

    if (modemCheck.isEmpty) {
      // Insert new modem
      final insertRes = await db.query(
        '''
        INSERT INTO modem_info (user_id, mac_address, device_type, ip_address, signal_strength, last_synced)
        VALUES (@userId, @mac, @type, @ip, @signal, NOW())
        RETURNING *
        ''',
        substitutionValues: {
          'userId': id,
          'mac': macAddress,
          'type': deviceType,
          'ip': ipAddress,
          'signal': defaultSignalStrength,
        },
      );
      modemData = insertRes.first.toColumnMap();
    } else {
      // Update existing modem
      final updateRes = await db.query(
        '''
        UPDATE modem_info 
        SET mac_address = @mac, device_type = @type, ip_address = @ip, last_synced = NOW()
        WHERE user_id = @userId
        RETURNING *
        ''',
        substitutionValues: {
          'userId': id,
          'mac': macAddress,
          'type': deviceType,
          'ip': ipAddress,
        },
      );
      modemData = updateRes.first.toColumnMap();
    }

    final sanitizedData = <String, dynamic>{};
    for (final key in modemData.keys) {
      final val = modemData[key];
      if (val is DateTime) {
        sanitizedData[key] = val.toIso8601String();
      } else {
        sanitizedData[key] = val;
      }
    }

    return ApiResponse.success(
      message: 'Modem linked successfully',
      data: sanitizedData,
    );
  } catch (e) {
    return ApiResponse.error(message: 'Failed to link modem: $e');
  }
}
