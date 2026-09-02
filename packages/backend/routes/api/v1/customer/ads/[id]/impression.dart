import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/ads/:id/impression
/// Increments the impressions count for a specific ad.
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final db = context.read<PostgresService>();

  try {
    final result = await db.query(
      '''
      UPDATE ads
      SET impressions = COALESCE(impressions, 0) + 1
      WHERE id = @id
      RETURNING id, title, impressions
      ''',
      substitutionValues: {'id': id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Ad campaign not found',
        statusCode: HttpStatus.notFound,
      );
    }

    final row = result.first.toColumnMap();

    return ApiResponse.success(
      message: 'Impression recorded successfully',
      data: {
        'id': row['id']?.toString(),
        'title': row['title']?.toString(),
        'impressions': row['impressions'],
      },
    );
  } catch (e) {
    return ApiResponse.error(message: 'Error recording impression: $e');
  }
}
