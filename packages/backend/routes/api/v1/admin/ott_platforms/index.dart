import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/admin/ott_platforms → List all OTT platforms
/// POST /api/v1/admin/ott_platforms → Create a new OTT platform
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── GET: List OTT Platforms ──────────────────────────────
  if (request.method == HttpMethod.get) {
    final params = request.uri.queryParameters;
    final includeInactive = params['include_inactive'] == 'true';

    var where = includeInactive ? '' : 'WHERE is_active = true';

    final result = await db.query(
      'SELECT * FROM ott_platforms $where ORDER BY display_order ASC, name ASC',
    );

    final platforms = result.map((r) {
      final row = r.toColumnMap();
      return <String, dynamic>{
        for (final e in row.entries)
          e.key: e.value is DateTime
              ? (e.value as DateTime).toIso8601String()
              : e.value,
      };
    }).toList();

    return ApiResponse.success(data: {
      'ott_platforms': platforms,
      'total': platforms.length,
    });
  }

  // ── POST: Create OTT Platform ────────────────────────────
  if (request.method == HttpMethod.post) {
    try {
      final body = await request.json() as Map<String, dynamic>;
      final name = body['name'] as String?;

      if (name == null || name.trim().isEmpty) {
        return ApiResponse.error(message: 'Platform name is required');
      }

      final result = await db.query(
        '''
        INSERT INTO ott_platforms (name, logo_url, color, display_order, is_active)
        VALUES (@name, @logoUrl, @color, @displayOrder, @isActive)
        RETURNING *
        ''',
        substitutionValues: {
          'name': name.trim(),
          'logoUrl': body['logo_url'],
          'color': body['color'],
          'displayOrder': body['display_order'] ?? 100,
          'isActive': body['is_active'] ?? true,
        },
      );

      final row = result.first.toColumnMap();
      final safe = <String, dynamic>{
        for (final e in row.entries)
          e.key: e.value is DateTime
              ? (e.value as DateTime).toIso8601String()
              : e.value,
      };

      return ApiResponse.success(
        message: 'OTT platform created successfully',
        statusCode: HttpStatus.created,
        data: safe,
      );
    } catch (e) {
      if (e.toString().contains('unique') || e.toString().contains('duplicate')) {
        return ApiResponse.error(message: 'An OTT platform with this name already exists');
      }
      return ApiResponse.error(message: 'Failed to create OTT platform: $e');
    }
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
