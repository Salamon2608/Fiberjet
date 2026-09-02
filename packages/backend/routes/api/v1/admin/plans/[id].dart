import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET    /api/v1/admin/plans/<id> → Get a single plan
/// PUT    /api/v1/admin/plans/<id> → Update a plan
/// DELETE /api/v1/admin/plans/<id> → Soft-delete (deactivate) a plan
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── GET: Single Plan ─────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT * FROM plans WHERE id = @id LIMIT 1',
      substitutionValues: {'id': id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Plan not found',
        statusCode: HttpStatus.notFound,
      );
    }

    final row = result.first.toColumnMap();
    final safe = <String, dynamic>{
      for (final e in row.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toIso8601String()
            : e.value,
    };

    return ApiResponse.success(data: safe);
  }

  // ── PUT: Update Plan ─────────────────────────────────────
  if (request.method == HttpMethod.put) {
    try {
      final body = await request.json() as Map<String, dynamic>;

      // Build SET clause dynamically from supplied fields
      final setClauses = <String>[];
      final subs = <String, dynamic>{'id': id};

      void addField(String dbCol, String jsonKey, {bool isJson = false}) {
        if (body.containsKey(jsonKey)) {
          if (isJson) {
            setClauses.add('$dbCol = @$jsonKey::jsonb');
            subs[jsonKey] = body[jsonKey] != null ? jsonEncode(body[jsonKey]) : null;
          } else {
            setClauses.add('$dbCol = @$jsonKey');
            subs[jsonKey] = body[jsonKey];
          }
        }
      }

      addField('name', 'name');
      addField('description', 'description');
      addField('speed_mbps', 'speed_mbps');
      addField('price', 'price');
      addField('data_limit_gb', 'data_limit_gb');
      addField('cloud_storage_gb', 'cloud_storage_gb');
      addField('ott_benefits', 'ott_benefits', isJson: true);
      addField('validity_days', 'validity_days');
      addField('is_active', 'is_active');
      addField('category', 'category');
      addField('badge', 'badge');
      addField('data_per_day_gb', 'data_per_day_gb');
      addField('fup_speed_mbps', 'fup_speed_mbps');
      addField('priority', 'priority');

      if (setClauses.isEmpty) {
        return ApiResponse.error(message: 'No fields to update');
      }

      final result = await db.query(
        '''
        UPDATE plans
        SET ${setClauses.join(', ')}
        WHERE id = @id
        RETURNING *
        ''',
        substitutionValues: subs,
      );

      if (result.isEmpty) {
        return ApiResponse.error(
          message: 'Plan not found',
          statusCode: HttpStatus.notFound,
        );
      }

      final row = result.first.toColumnMap();
      final safe = <String, dynamic>{
        for (final e in row.entries)
          e.key: e.value is DateTime
              ? (e.value as DateTime).toIso8601String()
              : e.value,
      };

      return ApiResponse.success(
        message: 'Plan updated successfully',
        data: safe,
      );
    } catch (e) {
      return ApiResponse.error(message: 'Failed to update plan: $e');
    }
  }

  // ── DELETE: Deactivate Plan ──────────────────────────────
  if (request.method == HttpMethod.delete) {
    final result = await db.query(
      '''
      UPDATE plans SET is_active = false
      WHERE id = @id
      RETURNING id, name, is_active
      ''',
      substitutionValues: {'id': id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Plan not found',
        statusCode: HttpStatus.notFound,
      );
    }

    return ApiResponse.success(message: 'Plan deactivated successfully');
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
