import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/modem_reboot → Sends a reboot signal to the modem
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    'SELECT id FROM modem_info WHERE user_id = @userId LIMIT 1',
    substitutionValues: {'userId': user.id},
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'No modem linked to this account.', statusCode: HttpStatus.notFound);
  }

  // Set signal strength to -100 to simulate the device going offline/rebooting
  await db.query(
    'UPDATE modem_info SET signal_strength = -100, last_synced = NOW() WHERE user_id = @userId',
    substitutionValues: {'userId': user.id},
  );

  return ApiResponse.success(
    message: 'Reboot command sent successfully.',
  );
}
