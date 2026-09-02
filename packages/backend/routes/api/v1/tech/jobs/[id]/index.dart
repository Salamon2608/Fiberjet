import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET   /api/v1/tech/jobs/:id → Detailed job view with checklist
/// PATCH /api/v1/tech/jobs/:id → Update job data (checklist, scheduled_at)
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Job Details ──────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT j.*, u.name as customer_name, u.phone as customer_phone
      FROM jobs j
      JOIN users u ON j.customer_id = u.id
      WHERE j.id = @id AND j.technician_id = @techId
      LIMIT 1
      ''',
      substitutionValues: {'id': id, 'techId': user.id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'Job not found', statusCode: HttpStatus.notFound);
    }

    // Get job photos too
    final photosResult = await db.query(
      'SELECT id, photo_type, file_path, uploaded_at FROM job_photos WHERE job_id = @id',
      substitutionValues: {'id': id},
    );

    final job = result.first.toColumnMap();
    job.remove('visit_otp'); // Secured: tech must ask customer in person
    job['photos'] = photosResult.map((r) => r.toColumnMap()).toList();

    return ApiResponse.success(data: job);
  }

  // ── PATCH: Update Job ─────────────────────────────────────
  if (request.method == HttpMethod.patch) {
    final body = await request.json() as Map<String, dynamic>;
    
    final updates = <String>[];
    final values = <String, dynamic>{'id': id, 'techId': user.id};

    if (body.containsKey('checklist')) {
      updates.add('checklist = @checklist');
      values['checklist'] = body['checklist']; // Should be JSONB
    }
    if (body.containsKey('scheduled_at')) {
      updates.add('scheduled_at = @scheduled');
      values['scheduled'] = body['scheduled_at'];
    }

    if (updates.isEmpty) {
      return ApiResponse.error(message: 'No fields provided for update');
    }

    final result = await db.query(
      '''
      UPDATE jobs 
      SET ${updates.join(', ')}
      WHERE id = @id AND technician_id = @techId
      RETURNING *
      ''',
      substitutionValues: values,
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'Job not found or update failed', statusCode: HttpStatus.notFound);
    }

    return ApiResponse.success(
      message: 'Job updated successfully',
      data: result.first.toColumnMap(),
    );
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
