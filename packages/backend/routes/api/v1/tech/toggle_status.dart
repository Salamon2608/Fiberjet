import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/toggle_status → Toggle online/offline status
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final isOnline = body['is_online'] as bool?;

  if (isOnline == null) {
    return ApiResponse.error(message: 'is_online boolean is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    '''
    UPDATE users 
    SET is_online = @isOnline 
    WHERE id = @techId
    RETURNING id, is_online
    ''',
    substitutionValues: {
      'techId': user.id,
      'isOnline': isOnline,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
  }

  return ApiResponse.success(
    message: 'Status updated',
    data: result.first.toColumnMap(),
  );
}
