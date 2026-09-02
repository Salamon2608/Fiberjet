import 'dart:io';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';
import 'package:dart_frog/dart_frog.dart';

/// PUT /api/v1/technicians/location
/// Expects { "lat": 12.34, "lng": 56.78 }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.put) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final (user, authError) = await AuthHelper.authenticate(context);
  if (user == null) return authError!;

  // Optional: check if role is technician (or admin testing)
  if (user.role.name != 'technician' && user.role.name != 'admin') {
    return ApiResponse.error(
      message: 'Only technicians can update their live location.',
      statusCode: HttpStatus.forbidden,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final lat = body['lat'];
  final lng = body['lng'];

  if (lat == null || lng == null) {
    return ApiResponse.error(message: 'lat and lng are required');
  }

  final db = context.read<PostgresService>();

  // PostgreSQL POINT format is (x, y) which translates to (longitude, latitude)
  await db.query(
    'UPDATE users SET location = point(@lng, @lat), '
    'updated_at = NOW() WHERE id = @id',
    substitutionValues: {
      'lat': lat,
      'lng': lng,
      'id': user.id,
    },
  );

  return ApiResponse.success(message: 'Location updated successfully');
}
