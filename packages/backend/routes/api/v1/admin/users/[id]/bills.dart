import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/admin/users/[id]/bills
Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final db = context.read<PostgresService>();

  try {
    // Generate bill history from user_plans and plans
    final result = await db.query(
      '''
      SELECT up.id as invoice_id, p.name as plan_name, p.price as amount, 
             up.start_date, up.expiry_date, up.status, up.data_used_gb
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = @userId
      ORDER BY up.start_date DESC
      ''',
      substitutionValues: {'userId': id},
    );

    final bills = result.map((r) {
      final map = r.toColumnMap();
      return <String, dynamic>{
        for (final entry in map.entries)
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value is num ? entry.value.toString() : entry.value,
      };
    }).toList();

    return ApiResponse.success(data: bills);
  } catch (e) {
    return ApiResponse.error(message: 'Failed to fetch billing history: $e');
  }
}
