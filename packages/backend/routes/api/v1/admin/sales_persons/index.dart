import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/sales_persons → List sales reps with performance stats
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  final result = await db.query('''
    SELECT u.id, u.name, u.email, u.phone, u.status, u.created_at,
           COUNT(DISTINCT l.id) as total_leads,
           SUM(CASE WHEN l.stage = 'installed' THEN 1 ELSE 0 END) as converted_leads,
           COALESCE(SUM(c.amount), 0) as total_commission
    FROM users u
    JOIN roles r ON u.role_id = r.id
    LEFT JOIN leads l ON u.id = l.sales_person_id
    LEFT JOIN commissions c ON u.id = c.sales_person_id
    WHERE r.name = 'sales'
    GROUP BY u.id, u.name, u.email, u.phone, u.status, u.created_at
    ORDER BY u.created_at DESC
  ''');

  final salesPersons = result.map((r) {
    final row = r.toColumnMap();
    return <String, dynamic>{
      for (final entry in row.entries)
        entry.key: entry.value is DateTime
            ? (entry.value as DateTime).toIso8601String()
            : entry.value,
    };
  }).toList();
  return ApiResponse.success(data: {'sales_persons': salesPersons});
}
