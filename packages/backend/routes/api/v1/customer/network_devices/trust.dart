import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/network_devices/trust
/// Body: { "mac_address": "AA:BB:CC:DD:EE:FF" }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final macAddress = body['mac_address'] as String?;

  if (macAddress == null || macAddress.isEmpty) {
    return ApiResponse.error(message: 'mac_address is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Verify the device belongs to this user
  final deviceCheck = await db.query(
    'SELECT id FROM network_devices WHERE mac_address = @mac AND user_id = @userId LIMIT 1',
    substitutionValues: {
      'mac': macAddress,
      'userId': user.id,
    },
  );

  if (deviceCheck.isEmpty) {
    return ApiResponse.error(
      message: 'Device not found',
      statusCode: HttpStatus.notFound,
    );
  }

  await db.query(
    '''
    UPDATE network_devices
    SET is_trusted = true, is_blocked = false
    WHERE mac_address = @mac AND user_id = @userId
    ''',
    substitutionValues: {
      'mac': macAddress,
      'userId': user.id,
    },
  );

  return ApiResponse.success(message: 'Device marked as trusted');
}
