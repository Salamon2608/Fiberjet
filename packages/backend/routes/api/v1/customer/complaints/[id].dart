import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context, String id) async {
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
    SELECT c.*, u.name as assigned_to_name
    FROM complaints c
    LEFT JOIN users u ON c.assigned_to = u.id
    WHERE c.id = @id AND c.user_id = @userId
    LIMIT 1
    ''',
    substitutionValues: {
      'id': id,
      'userId': user.id,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(
      message: 'Complaint not found',
      statusCode: HttpStatus.notFound,
    );
  }

  return ApiResponse.success(data: result.first.toColumnMap());
}
