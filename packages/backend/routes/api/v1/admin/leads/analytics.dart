import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/leads/analytics → Analytics for leads
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  // Get conversion rate
  final totalResult = await db.query('SELECT COUNT(id) as c FROM leads');
  final convertedResult = await db.query(
    "SELECT COUNT(id) as c FROM leads WHERE stage = 'converted'",
  );

  final total = _parseInt(totalResult.first.toColumnMap()['c']);
  final converted = _parseInt(convertedResult.first.toColumnMap()['c']);
  final conversionRate = total > 0 ? (converted / total) * 100 : 0.0;

  // Top performing sales reps
  final topRepsResult = await db.query('''
    SELECT u.name, COUNT(l.id) as converted_leads
    FROM leads l
    JOIN users u ON l.sales_person_id = u.id
    WHERE l.stage = 'converted'
    GROUP BY u.name
    ORDER BY converted_leads DESC
    LIMIT 5
  ''');

  final topReps = topRepsResult.map((r) => r.toColumnMap()).map((m) {
    return {
      'name': m['name'],
      'converted_leads': _parseInt(m['converted_leads']),
    };
  }).toList();

  return ApiResponse.success(
    data: {
      'conversion_rate': conversionRate,
      'total_leads': total,
      'converted_leads': converted,
      'top_reps': topReps,
    },
  );
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
