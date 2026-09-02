import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/customer/modem_info → Returns the user's modem/ONT information
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    '''
    SELECT * FROM modem_info
    WHERE user_id = @userId
    ORDER BY last_synced DESC NULLS LAST
    LIMIT 1
    ''',
    substitutionValues: {'userId': user.id},
  );

  if (result.isEmpty) {
    return ApiResponse.success(
      data: null,
      message: 'No modem information found for your account',
    );
  }

  final modem = result.first.toColumnMap();

  return ApiResponse.success(
    data: {
      'id': modem['id'],
      'mac_address': modem['mac_address'],
      'device_type': modem['device_type'],
      'ip_address': modem['ip_address'],
      'signal_strength': modem['signal_strength'],
      'last_synced': modem['last_synced']?.toString(),
    },
  );
}
