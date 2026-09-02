import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// PUT    /api/v1/admin/categories/<id> → Update a category
/// DELETE /api/v1/admin/categories/<id> → Delete (deactivate) a category
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── PUT: Update Category ─────────────────────────────────
  if (request.method == HttpMethod.put) {
    try {
      final body = await request.json() as Map<String, dynamic>;
      final setClauses = <String>[];
      final subs = <String, dynamic>{'id': id};

      if (body.containsKey('name')) {
        setClauses.add('name = @name');
        subs['name'] = body['name'];
      }
      if (body.containsKey('icon')) {
        setClauses.add('icon = @icon');
        subs['icon'] = body['icon'];
      }
      if (body.containsKey('color')) {
        setClauses.add('color = @color');
        subs['color'] = body['color'];
      }
      if (body.containsKey('display_order')) {
        setClauses.add('display_order = @displayOrder');
        subs['displayOrder'] = body['display_order'];
      }
      if (body.containsKey('is_active')) {
        setClauses.add('is_active = @isActive');
        subs['isActive'] = body['is_active'];
      }

      if (setClauses.isEmpty) {
        return ApiResponse.error(message: 'No fields to update');
      }

      final result = await db.query(
        'UPDATE plan_categories SET ${setClauses.join(', ')} WHERE id = @id RETURNING *',
        substitutionValues: subs,
      );

      if (result.isEmpty) {
        return ApiResponse.error(message: 'Category not found', statusCode: HttpStatus.notFound);
      }

      final row = result.first.toColumnMap();
      final safe = <String, dynamic>{
        for (final e in row.entries)
          e.key: e.value is DateTime ? (e.value as DateTime).toIso8601String() : e.value,
      };

      return ApiResponse.success(message: 'Category updated', data: safe);
    } catch (e) {
      return ApiResponse.error(message: 'Failed to update category: $e');
    }
  }

  // ── DELETE: Deactivate Category ──────────────────────────
  if (request.method == HttpMethod.delete) {
    final result = await db.query(
      'UPDATE plan_categories SET is_active = false WHERE id = @id RETURNING id, name',
      substitutionValues: {'id': id},
    );
    if (result.isEmpty) {
      return ApiResponse.error(message: 'Category not found', statusCode: HttpStatus.notFound);
    }
    return ApiResponse.success(message: 'Category deactivated');
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
