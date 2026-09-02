import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/sales_persons/[id]/documents
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  try {
    final result = await db.query(
      'SELECT kyc_doc_paths FROM users WHERE id = @id',
      substitutionValues: {'id': id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'User not found', statusCode: HttpStatus.notFound);
    }

    final row = result.first.toColumnMap();
    final docs = row['kyc_doc_paths'] as Map<String, dynamic>? ?? {};

    // In a real scenario, this would call Nextcloud API to generate temporary share links.
    // For now, we return the parsed JSON.
    return ApiResponse.success(data: docs);
  } catch (e) {
    return ApiResponse.error(message: 'Failed to fetch documents: $e');
  }
}
