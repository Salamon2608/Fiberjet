import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();
  final params = context.request.uri.queryParameters;
  final category = params['category'];

  var whereClause = 'WHERE is_active = true';
  final subs = <String, dynamic>{};

  if (category != null && category.isNotEmpty) {
    whereClause += ' AND category = @category';
    subs['category'] = category;
  }

  // Fetch all active plans, ordered by category then priority
  final result = await db.query(
    '''
    SELECT * FROM plans 
    $whereClause
    ORDER BY category ASC, priority ASC, price ASC
    ''',
    substitutionValues: subs.isNotEmpty ? subs : null,
  );

  final plans = result.map((r) {
    final row = r.toColumnMap();
    return <String, dynamic>{
      for (final entry in row.entries)
        entry.key: entry.value is DateTime
            ? (entry.value as DateTime).toIso8601String()
            : entry.value,
    };
  }).toList();

  // Get categories for tab navigation
  final catResult = await db.query(
    "SELECT DISTINCT category FROM plans WHERE is_active = true AND category IS NOT NULL ORDER BY category",
  );
  final categories = catResult.map((r) => r.toColumnMap()['category']?.toString() ?? '').where((c) => c.isNotEmpty).toList();

  return ApiResponse.success(data: {
    'plans': plans,
    'categories': categories,
  });
}
