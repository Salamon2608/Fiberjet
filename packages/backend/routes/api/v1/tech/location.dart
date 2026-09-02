import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/location → Update technician GPS
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final latitude = body['latitude'];
  final longitude = body['longitude'];

  if (latitude == null || longitude == null) {
    return ApiResponse.error(message: 'latitude and longitude are required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  await db.query(
    '''
    UPDATE users SET
      location = POINT(@lat, @lng),
      updated_at = NOW()
    WHERE id = @userId
    ''',
    substitutionValues: {
      'userId': user.id,
      'lat': latitude,
      'lng': longitude,
    },
  );

  return ApiResponse.success(message: 'Location updated');
}
