import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/sales/technicians → List all technicians with their online status
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
        message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  try {
    final result = await db.query(
      '''
      SELECT u.id, u.name, u.phone, COALESCE(u.is_online, false) as is_online
      FROM users u
      JOIN roles r ON u.role_id = r.id
      WHERE r.name = 'technician' AND u.status = 'active'
      ORDER BY u.name ASC
      ''',
    );

    final technicians = result.map((r) => r.toColumnMap()).toList();

    return ApiResponse.success(data: {'technicians': technicians});
  } catch (e) {
    return ApiResponse.error(message: 'Error fetching technicians: $e');
  }
}
