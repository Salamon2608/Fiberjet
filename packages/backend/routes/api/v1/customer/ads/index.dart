import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/customer/ads
/// Lists active and scheduled promotions/ads for the customer.
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
    final result = await db.query(
      '''
      SELECT * FROM ads
      WHERE is_active = true
        AND (start_date IS NULL OR start_date <= CURRENT_DATE)
        AND (end_date IS NULL OR end_date >= CURRENT_DATE)
      ORDER BY created_at DESC
      ''',
    );

    final ads = result.map((r) {
      final row = r.toColumnMap();
      return <String, dynamic>{
        for (final entry in row.entries)
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value is bool ||
                      entry.value is int ||
                      entry.value is double ||
                      entry.value == null
                  ? entry.value
                  : entry.value.toString(),
      };
    }).toList();

    return ApiResponse.success(data: {'ads': ads});
  } catch (e) {
    return ApiResponse.error(message: 'Error fetching ads: $e');
  }
}
