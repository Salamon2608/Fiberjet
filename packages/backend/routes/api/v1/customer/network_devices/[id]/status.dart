import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final accessLevel = body['access_level'] as String?;

  if (accessLevel == null || !['trusted', 'blocked', 'unknown'].contains(accessLevel)) {
    return ApiResponse.error(message: 'Invalid access_level. Must be trusted, blocked, or unknown.');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    'UPDATE connected_devices SET access_level = @accessLevel WHERE id = @id AND user_id = @userId RETURNING id',
    substitutionValues: {
      'accessLevel': accessLevel,
      'id': id,
      'userId': user.id,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'Device not found', statusCode: HttpStatus.notFound);
  }

  return ApiResponse.success(message: 'Device status updated to $accessLevel');
}
