import 'dart:io';

import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:dart_frog/dart_frog.dart';

/// PUT    /api/v1/admin/ads/:id → Update ad or toggle active
/// DELETE /api/v1/admin/ads/:id → Remove ad
Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── PUT: Update Ad ────────────────────────────────────────
  if (request.method == HttpMethod.put) {
    final body =
        await request.json() as Map<String, dynamic>;

    final updates = <String>[];
    final values = <String, dynamic>{'id': id};

    if (body.containsKey('title')) {
      updates.add('title = @title');
      values['title'] = body['title'];
    }
    if (body.containsKey('image_path')) {
      updates.add('image_path = @imagePath');
      values['imagePath'] = body['image_path'];
    }
    if (body.containsKey('is_active')) {
      updates.add('is_active = @isActive');
      values['isActive'] = body['is_active'];
    }
    if (body.containsKey('start_date')) {
      updates.add('start_date = @startDate');
      values['startDate'] = body['start_date'];
    }
    if (body.containsKey('end_date')) {
      updates.add('end_date = @endDate');
      values['endDate'] = body['end_date'];
    }

    if (updates.isEmpty) {
      return ApiResponse.error(
        message: 'No fields provided for update',
      );
    }

    final result = await db.query(
      'UPDATE ads SET ${updates.join(', ')} '
      'WHERE id = @id RETURNING *',
      substitutionValues: values,
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Ad not found',
        statusCode: HttpStatus.notFound,
      );
    }

    // Safely convert DateTime values to strings
    final row = result.first.toColumnMap();
    final safe = <String, dynamic>{
      for (final e in row.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toIso8601String()
            : e.value,
    };

    return ApiResponse.success(
      message: 'Ad updated',
      data: safe,
    );
  }

  // ── DELETE: Remove Ad ─────────────────────────────────────
  if (request.method == HttpMethod.delete) {
    final result = await db.query(
      'DELETE FROM ads WHERE id = @id '
      'RETURNING id, title',
      substitutionValues: {'id': id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Ad not found',
        statusCode: HttpStatus.notFound,
      );
    }

    return ApiResponse.success(
      message: 'Ad deleted successfully',
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
