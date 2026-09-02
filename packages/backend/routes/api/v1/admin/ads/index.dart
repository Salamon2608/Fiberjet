import 'dart:io';

import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:path/path.dart' as p;

/// GET  /api/v1/admin/ads → List all ads
/// POST /api/v1/admin/ads → Create a new ad
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final db = context.read<PostgresService>();

  // ── GET: List Ads ─────────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT * FROM ads ORDER BY created_at DESC',
    );
    final ads = result.map((r) {
      final row = r.toColumnMap();
      return <String, dynamic>{
        for (final entry in row.entries)
          entry.key: entry.value is DateTime
              ? (entry.value as DateTime).toIso8601String()
              : entry.value is bool ||
                      entry.value is int ||
                      entry.value is double ||
                      entry.value == null
                  ? entry.value
                  : entry.value.toString(),
      };
    }).toList();
    return ApiResponse.success(data: {'ads': ads});
  }

  // ── POST: Create Ad ───────────────────────────────────────
  if (request.method == HttpMethod.post) {
    String? title;
    String? imagePath;
    var targetRoles = <String>[];
    String? startDate;
    String? endDate;

    final contentType =
        request.headers['content-type'] ?? '';

    if (contentType.contains('multipart/form-data')) {
      // ── Dart Frog native multipart parsing ──
      final formData = await request.formData();

      // Read text fields
      title = formData.fields['title'];
      final rolesStr = formData.fields['target_roles'];
      if (rolesStr != null && rolesStr.isNotEmpty) {
        targetRoles = rolesStr
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      startDate = formData.fields['start_date'];
      endDate = formData.fields['end_date'];
      imagePath = formData.fields['image_url'];

      // Read uploaded file (if any)
      final uploadedFile = formData.files['image'];
      if (uploadedFile != null) {
        final ts = DateTime.now().millisecondsSinceEpoch;
        final safeName = '${ts}_${uploadedFile.name}';
        final uploadDir = Directory(
          p.join(
            Directory.current.path,
            'uploads',
          ),
        );
        if (!uploadDir.existsSync()) {
          uploadDir.createSync(recursive: true);
        }
        final dest = File(p.join(uploadDir.path, safeName));
        final bytes = await uploadedFile.readAsBytes();
        await dest.writeAsBytes(bytes);
        imagePath = '/uploads/$safeName';
      }
    } else {
      // ── Standard JSON body ──
      final body =
          await request.json() as Map<String, dynamic>;
      title = body['title'] as String?;
      imagePath = body['image_path'] as String? ??
          body['image_url'] as String?;
      targetRoles =
          (body['target_roles'] as List?)
                  ?.cast<String>() ??
              [];
      startDate = body['start_date'] as String?;
      endDate = body['end_date'] as String?;
    }

    if (title == null || imagePath == null) {
      return ApiResponse.error(
        message:
            'title and image (or image_url) are required',
      );
    }

    final result = await db.query(
      '''
      INSERT INTO ads
        (title, image_path, target_roles,
         start_date, end_date, is_active)
      VALUES
        (@title, @imagePath, @targetRoles,
         @startDate, @endDate, true)
      RETURNING *
      ''',
      substitutionValues: {
        'title': title,
        'imagePath': imagePath,
        'targetRoles': targetRoles,
        'startDate': startDate,
        'endDate': endDate,
      },
    );

    // Safely convert DateTime values to strings
    final row = result.first.toColumnMap();
    final safe = <String, dynamic>{
      for (final e in row.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toIso8601String()
            : e.value,
    };

    return ApiResponse.success(
      message: 'Ad created successfully',
      statusCode: HttpStatus.created,
      data: safe,
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
