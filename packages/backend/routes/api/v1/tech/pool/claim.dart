import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/pool/claim → Claim a task (job or complaint) atomically
/// Body: { "task_type": "job" | "complaint", "task_id": "uuid" }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final taskType = body['task_type'] as String?;
  final taskId = body['task_id'] as String?;

  if (taskType == null || taskId == null) {
    return ApiResponse.error(message: 'task_type and task_id are required');
  }

  if (taskType != 'job' && taskType != 'complaint') {
    return ApiResponse.error(message: 'task_type must be either "job" or "complaint"');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  try {
    if (taskType == 'job') {
      // Claim unassigned installation job atomically
      final result = await db.query(
        '''
        UPDATE jobs
        SET technician_id = @techId, status = 'pending'
        WHERE id = @jobId AND technician_id IS NULL
        RETURNING id
        ''',
        substitutionValues: {
          'jobId': taskId,
          'techId': user.id,
        },
      );

      if (result.isEmpty) {
        return ApiResponse.error(
          message: 'Job has already been claimed by another technician or does not exist.',
          statusCode: HttpStatus.conflict,
        );
      }

      // Log the claim action
      try {
        await db.query(
          '''
          INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
          VALUES (@techId, 'claim_job', 'jobs', @jobId,
            jsonb_build_object('technician_name', @techName, 'status', 'claimed'))
          ''',
          substitutionValues: {
            'techId': user.id,
            'jobId': taskId,
            'techName': user.name,
          },
        );
      } catch (_) {}

      return ApiResponse.success(
        message: 'Installation job claimed successfully',
        data: {'id': taskId},
      );
    } else {
      // Claim unassigned support ticket (complaint) atomically
      final result = await db.query(
        '''
        UPDATE complaints
        SET assigned_to = @techId, status = 'in_progress', updated_at = NOW()
        WHERE id = @complaintId AND assigned_to IS NULL
        RETURNING id
        ''',
        substitutionValues: {
          'complaintId': taskId,
          'techId': user.id,
        },
      );

      if (result.isEmpty) {
        return ApiResponse.error(
          message: 'Ticket has already been claimed by another technician or does not exist.',
          statusCode: HttpStatus.conflict,
        );
      }

      // Log the claim action
      try {
        await db.query(
          '''
          INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
          VALUES (@techId, 'claim_complaint', 'complaints', @complaintId,
            jsonb_build_object('technician_name', @techName, 'status', 'claimed'))
          ''',
          substitutionValues: {
            'techId': user.id,
            'complaintId': taskId,
            'techName': user.name,
          },
        );
      } catch (_) {}

      return ApiResponse.success(
        message: 'Support ticket claimed successfully',
        data: {'id': taskId},
      );
    }
  } catch (e) {
    return ApiResponse.error(message: 'Error claiming task: $e');
  }
}
