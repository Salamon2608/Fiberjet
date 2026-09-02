import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/customer/cloud_drive/:id/link → Generate a temporary download link
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    '''
    SELECT file_path, file_name, nc_file_path, nc_share_token
    FROM cloud_files
    WHERE id = @id AND user_id = @userId AND is_deleted = false
    LIMIT 1
    ''',
    substitutionValues: {
      'id': id,
      'userId': user.id,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(
      message: 'File not found',
      statusCode: HttpStatus.notFound,
    );
  }

  final file = result.first.toColumnMap();
  final filePath = file['file_path'] as String;
  final ncShareToken = file['nc_share_token'] as String?;

  // If Nextcloud share token exists, use it; otherwise generate a local path
  String downloadUrl;
  if (ncShareToken != null && ncShareToken.isNotEmpty) {
    // Nextcloud public share link
    downloadUrl = '/s/$ncShareToken/download';
  } else {
    // Local storage path — served via static file handler
    downloadUrl = '/api/v1/files/$filePath';
  }

  return ApiResponse.success(
    data: {
      'file_name': file['file_name'],
      'download_url': downloadUrl,
      'expires_in': '3600', // 1 hour (placeholder for signed URLs)
    },
  );
}
