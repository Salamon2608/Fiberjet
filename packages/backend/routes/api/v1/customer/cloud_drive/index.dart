import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/services/storage_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/customer/cloud_drive → List user's cloud files
/// POST /api/v1/customer/cloud_drive → Upload a new file
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List files ────────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final folder = request.url.queryParameters['folder'] ?? '';
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;
    final offset = (page - 1) * limit;

    String whereClause = 'WHERE user_id = @userId AND is_deleted = false';
    final values = <String, dynamic>{
      'userId': user.id,
      'limit': limit,
      'offset': offset,
    };

    if (folder.isNotEmpty) {
      whereClause += ' AND folder = @folder';
      values['folder'] = folder;
    }

    final result = await db.query(
      '''
      SELECT id, file_name, file_type, file_size_mb, folder, created_at
      FROM cloud_files
      $whereClause
      ORDER BY created_at DESC
      LIMIT @limit OFFSET @offset
      ''',
      substitutionValues: values,
    );

    // Get usage stats
    final usageResult = await db.query(
      '''
      SELECT COALESCE(SUM(file_size_mb), 0) as used_mb, COUNT(*) as file_count
      FROM cloud_files
      WHERE user_id = @userId AND is_deleted = false
      ''',
      substitutionValues: {'userId': user.id},
    );

    final usage = usageResult.first.toColumnMap();
    final files = result.map((r) => r.toColumnMap()).toList();

    // Get plan's cloud storage quota
    final quotaResult = await db.query(
      '''
      SELECT p.cloud_storage_gb
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.user_id = @userId AND up.status = 'active'
      LIMIT 1
      ''',
      substitutionValues: {'userId': user.id},
    );

    final quotaGb = quotaResult.isNotEmpty
        ? (quotaResult.first.toColumnMap()['cloud_storage_gb'] as num?)?.toDouble() ?? 0
        : 0.0;

    return ApiResponse.success(
      data: {
        'files': files,
        'storage': {
          'used_mb': usage['used_mb'],
          'file_count': usage['file_count'],
          'quota_gb': quotaGb,
          'quota_mb': quotaGb * 1024,
        },
        'page': page,
        'limit': limit,
      },
    );
  }

  // ── POST: Upload a file record ─────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final fileName = body['file_name'] as String?;
    final fileType = body['file_type'] as String?;
    final fileSizeMb = body['file_size_mb'] as num?;
    final folder = body['folder'] as String? ?? '';
    final filePath = body['file_path'] as String?;

    if (fileName == null || filePath == null) {
      return ApiResponse.error(
        message: 'file_name and file_path are required',
      );
    }

    final result = await db.query(
      '''
      INSERT INTO cloud_files (user_id, file_name, file_type, file_size_mb, folder, file_path)
      VALUES (@userId, @fileName, @fileType, @fileSizeMb, @folder, @filePath)
      RETURNING id, file_name, file_type, file_size_mb, folder, created_at
      ''',
      substitutionValues: {
        'userId': user.id,
        'fileName': fileName,
        'fileType': fileType ?? 'unknown',
        'fileSizeMb': fileSizeMb ?? 0,
        'folder': folder,
        'filePath': filePath,
      },
    );

    return ApiResponse.success(
      message: 'File uploaded successfully',
      statusCode: HttpStatus.created,
      data: result.first.toColumnMap(),
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
