import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET    /api/v1/customer/cloud_drive/:id → Get file details
/// DELETE /api/v1/customer/cloud_drive/:id → Soft-delete a file
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: File detail ───────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT * FROM cloud_files
      WHERE id = @id AND user_id = @userId AND is_deleted = false
      LIMIT 1
      ''',
      substitutionValues: {
        'id': id,
        'userId': user.id,
      },
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'File not found',
        statusCode: HttpStatus.notFound,
      );
    }

    return ApiResponse.success(data: result.first.toColumnMap());
  }

  // ── DELETE: Soft-delete ────────────────────────────────────
  if (request.method == HttpMethod.delete) {
    final result = await db.query(
      '''
      UPDATE cloud_files
      SET is_deleted = true
      WHERE id = @id AND user_id = @userId AND is_deleted = false
      RETURNING id, file_name
      ''',
      substitutionValues: {
        'id': id,
        'userId': user.id,
      },
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'File not found or already deleted',
        statusCode: HttpStatus.notFound,
      );
    }

    return ApiResponse.success(message: 'File deleted successfully');
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
