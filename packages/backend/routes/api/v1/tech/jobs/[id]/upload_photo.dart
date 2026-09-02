import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/jobs/:id/upload_photo → Record a photo upload for a job
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final photoType = body['photo_type'] as String?;
  final filePath = body['file_path'] as String?;
  final ncFileId = body['nc_file_id'] as String?; // Optional Nextcloud ID

  if (photoType == null || filePath == null) {
    return ApiResponse.error(message: 'photo_type and file_path are required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Verify job assignment
  final jobCheck = await db.query(
    'SELECT id FROM jobs WHERE id = @id AND technician_id = @techId LIMIT 1',
    substitutionValues: {'id': id, 'techId': user.id},
  );

  if (jobCheck.isEmpty) {
    return ApiResponse.error(message: 'Job not found', statusCode: HttpStatus.notFound);
  }

  final result = await db.query(
    '''
    INSERT INTO job_photos (job_id, photo_type, file_path, nc_file_id)
    VALUES (@jobId, @type, @path, @ncId)
    RETURNING id, photo_type, file_path, uploaded_at
    ''',
    substitutionValues: {
      'jobId': id,
      'type': photoType,
      'path': filePath,
      'ncId': ncFileId,
    },
  );

  return ApiResponse.success(
    message: 'Photo recorded successfully',
    statusCode: HttpStatus.created,
    data: result.first.toColumnMap(),
  );
}
