import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/technicians/activities → Fetch chronological activity feed for all technicians
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  try {
    // Query audit_logs joined with users and roles to only show technician logs
    final result = await db.query(
      '''
      SELECT a.id, a.action, a.target_table, a.target_id, a.new_values, a.created_at,
             u.name as technician_name, u.phone as technician_phone
      FROM audit_logs a
      JOIN users u ON a.user_id = u.id
      JOIN roles r ON u.role_id = r.id
      WHERE r.name = 'technician'
      ORDER BY a.created_at DESC
      LIMIT 100
      ''',
    );

    final activities = result.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'action': map['action'],
        'target_table': map['target_table'],
        'target_id': map['target_id'],
        'new_values': map['new_values'],
        'created_at': map['created_at']?.toString(),
        'technician_name': map['technician_name'],
        'technician_phone': map['technician_phone'],
      };
    }).toList();

    return ApiResponse.success(data: {'activities': activities});
  } catch (e) {
    return ApiResponse.error(message: 'Error fetching activities: $e');
  }
}
