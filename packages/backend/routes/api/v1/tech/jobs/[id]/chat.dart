import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/tech/jobs/:id/chat → List chat messages for a job
/// POST /api/v1/tech/jobs/:id/chat → Send a new chat message
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List messages ────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT jc.*, u.name as sender_name
      FROM job_chats jc
      JOIN users u ON jc.sender_id = u.id
      WHERE jc.job_id = @jobId
      ORDER BY jc.created_at ASC
      ''',
      substitutionValues: {'jobId': id},
    );

    final messages = result.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'message': map['message'],
        'sender_id': map['sender_id'],
        'sender_name': map['sender_name'],
        'is_me': map['sender_id'].toString() == user.id,
        'created_at': map['created_at']?.toString(),
      };
    }).toList();

    return ApiResponse.success(data: messages);
  }

  // ── POST: Send message ────────────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final message = body['message'] as String?;

    if (message == null || message.trim().isEmpty) {
      return ApiResponse.error(message: 'message is required');
    }

    final result = await db.query(
      '''
      INSERT INTO job_chats (job_id, sender_id, message)
      VALUES (@jobId, @senderId, @message)
      RETURNING id, message, sender_id, created_at
      ''',
      substitutionValues: {
        'jobId': id,
        'senderId': user.id,
        'message': message.trim(),
      },
    );

    final created = result.first.toColumnMap();
    created['sender_name'] = user.name;
    created['is_me'] = true;

    return ApiResponse.success(
      message: 'Message sent',
      statusCode: HttpStatus.created,
      data: created,
    );
  }

  return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed);
}
