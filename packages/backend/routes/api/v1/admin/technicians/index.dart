import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/technicians → List technicians with job performance stats
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  final result = await db.query('''
    WITH tech_stats AS (
      SELECT u.id, u.name, u.email, u.phone, u.status, u.created_at,
             (SELECT COUNT(*)::int FROM jobs WHERE technician_id = u.id) as total_jobs,
             (SELECT COUNT(*)::int FROM jobs WHERE technician_id = u.id AND status = 'completed') as completed_jobs,
             (SELECT COUNT(*)::int FROM jobs WHERE technician_id = u.id AND status = 'pending') as pending_jobs,
             (SELECT COUNT(*)::int FROM complaints WHERE assigned_to = u.id AND status = 'resolved') as resolved_complaints,
             (SELECT COUNT(*)::int FROM complaints WHERE assigned_to = u.id AND status = 'in_progress') as active_complaints,
             COALESCE((SELECT AVG(stars) FROM ratings WHERE technician_id = u.id), 0) as avg_rating
      FROM users u
      JOIN roles r ON u.role_id = r.id
      WHERE r.name = 'technician'
    )
    SELECT * FROM tech_stats
    ORDER BY (completed_jobs + resolved_complaints) DESC
  ''');

  final technicians = result.map((r) {
    final row = r.toColumnMap();
    return <String, dynamic>{
      for (final entry in row.entries)
        entry.key: entry.value is DateTime
            ? (entry.value as DateTime).toIso8601String()
            : entry.value,
    };
  }).toList();
  return ApiResponse.success(data: {'technicians': technicians});
}
