import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/admin/jobs/:id/assign → Assign a job to a technician
/// Body: { "technician_id": "uuid" }
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final technicianId = body['technician_id'] as String?;

  if (technicianId == null) {
    return ApiResponse.error(message: 'technician_id is required');
  }

  final db = context.read<PostgresService>();

  // Verify technician exists and has the right role
  final techCheck = await db.query(
    '''
    SELECT u.id FROM users u
    JOIN roles r ON u.role_id = r.id
    WHERE u.id = @techId AND r.name = 'technician' AND u.status = 'active'
    LIMIT 1
    ''',
    substitutionValues: {'techId': technicianId},
  );

  if (techCheck.isEmpty) {
    return ApiResponse.error(
      message: 'Technician not found or inactive',
      statusCode: HttpStatus.notFound,
    );
  }

  // Assign the job
  final result = await db.query(
    '''
    UPDATE jobs 
    SET technician_id = @techId, status = 'assigned'
    WHERE id = @jobId
    RETURNING id, technician_id, status, type, customer_id
    ''',
    substitutionValues: {
      'jobId': id,
      'techId': technicianId,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'Job not found', statusCode: HttpStatus.notFound);
  }

  return ApiResponse.success(
    message: 'Job assigned to technician',
    data: result.first.toColumnMap(),
  );
}
