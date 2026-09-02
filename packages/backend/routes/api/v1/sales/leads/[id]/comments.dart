import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/sales/leads/:id/comments → List comments for a lead
/// POST /api/v1/sales/leads/:id/comments → Add a comment to a lead
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Verify lead ownership
  final leadCheck = await db.query(
    'SELECT id FROM leads WHERE id = @id AND sales_person_id = @salesId LIMIT 1',
    substitutionValues: {'id': id, 'salesId': user.id},
  );

  if (leadCheck.isEmpty) {
    return ApiResponse.error(message: 'Lead not found', statusCode: HttpStatus.notFound);
  }

  // ── GET: List Comments ────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT lc.*, u.name as user_name 
      FROM lead_comments lc
      JOIN users u ON lc.user_id = u.id
      WHERE lc.lead_id = @leadId
      ORDER BY lc.created_at DESC
      ''',
      substitutionValues: {'leadId': id},
    );

    final comments = result.map((r) => r.toColumnMap()).toList();
    return ApiResponse.success(data: {'comments': comments});
  }

  // ── POST: Add Comment ─────────────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final comment = body['comment'] as String?;
    final type = body['type'] as String? ?? 'general';

    if (comment == null || comment.isEmpty) {
      return ApiResponse.error(message: 'comment text is required');
    }

    final result = await db.query(
      '''
      INSERT INTO lead_comments (lead_id, user_id, comment, type)
      VALUES (@leadId, @userId, @comment, @type)
      RETURNING *
      ''',
      substitutionValues: {
        'leadId': id,
        'userId': user.id,
        'comment': comment,
        'type': type,
      },
    );

    return ApiResponse.success(
      message: 'Comment added successfully',
      statusCode: HttpStatus.created,
      data: result.first.toColumnMap(),
    );
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
