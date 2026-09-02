import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:path/path.dart' as p;

/// GET  /api/v1/sales/leads/:id/documents → Get document paths for a lead
/// POST /api/v1/sales/leads/:id/documents → Upload KYC documents for a lead
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Retrieve document paths ──────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      'SELECT kyc_doc_path FROM leads WHERE id = @id AND sales_person_id = @salesId LIMIT 1',
      substitutionValues: {'id': id, 'salesId': user.id},
    );

    if (result.isEmpty) {
      return ApiResponse.error(
        message: 'Lead not found',
        statusCode: HttpStatus.notFound,
      );
    }

    final row = result.first.toColumnMap();
    final kycPath = row['kyc_doc_path']?.toString();

    // Parse JSON string or return empty
    Map<String, dynamic> docs = {};
    if (kycPath != null && kycPath.isNotEmpty && kycPath != 'null') {
      try {
        docs = _parseDocPaths(kycPath);
      } catch (_) {
        docs = {'raw': kycPath};
      }
    }

    return ApiResponse.success(data: {'documents': docs});
  }

  // ── POST: Upload documents ────────────────────────────────
  if (request.method == HttpMethod.post) {
    // Verify lead belongs to this sales person
    final leadCheck = await db.query(
      'SELECT id FROM leads WHERE id = @id AND sales_person_id = @salesId LIMIT 1',
      substitutionValues: {'id': id, 'salesId': user.id},
    );

    if (leadCheck.isEmpty) {
      return ApiResponse.error(
        message: 'Lead not found',
        statusCode: HttpStatus.notFound,
      );
    }

    final contentType = request.headers['content-type'] ?? '';
    String? idProofUrl;
    String? addressProofUrl;

    if (contentType.contains('multipart/form-data')) {
      final formData = await request.formData();

      // Use the flat uploads directory (already served by /uploads/[id].dart)
      final uploadDir = Directory(
        p.join(Directory.current.path, 'uploads'),
      );
      if (!uploadDir.existsSync()) {
        uploadDir.createSync(recursive: true);
      }

      // Handle ID proof upload
      final idProofFile = formData.files['id_proof'];
      if (idProofFile != null) {
        var ext = p.extension(idProofFile.name).toLowerCase();
        if (ext.isEmpty) ext = '.jpg'; // Fallback for web uploads
        final safeName = 'kyc_${id}_id_proof$ext';
        final dest = File(p.join(uploadDir.path, safeName));
        final bytes = await idProofFile.readAsBytes();
        await dest.writeAsBytes(bytes);
        idProofUrl = '/uploads/$safeName';
      }

      // Handle address proof upload
      final addressProofFile = formData.files['address_proof'];
      if (addressProofFile != null) {
        var ext = p.extension(addressProofFile.name).toLowerCase();
        if (ext.isEmpty) ext = '.jpg'; // Fallback for web uploads
        final safeName = 'kyc_${id}_address_proof$ext';
        final dest = File(p.join(uploadDir.path, safeName));
        final bytes = await addressProofFile.readAsBytes();
        await dest.writeAsBytes(bytes);
        addressProofUrl = '/uploads/$safeName';
      }
    } else {
      return ApiResponse.error(
        message: 'Content-Type must be multipart/form-data',
      );
    }

    if (idProofUrl == null && addressProofUrl == null) {
      return ApiResponse.error(message: 'No files were uploaded');
    }

    // Build the JSON document paths
    // First, fetch existing doc paths
    final existingResult = await db.query(
      'SELECT kyc_doc_path FROM leads WHERE id = @id LIMIT 1',
      substitutionValues: {'id': id},
    );
    Map<String, dynamic> existingDocs = {};
    if (existingResult.isNotEmpty) {
      final existing = existingResult.first
          .toColumnMap()['kyc_doc_path']
          ?.toString();
      if (existing != null && existing.isNotEmpty && existing != 'null') {
        existingDocs = _parseDocPaths(existing);
      }
    }

    if (idProofUrl != null) existingDocs['id_proof'] = idProofUrl;
    if (addressProofUrl != null)
      existingDocs['address_proof'] = addressProofUrl;

    // Store as simple key=value string that's easy to parse
    final docPathStr =
        '{"id_proof":"${existingDocs['id_proof'] ?? ''}","address_proof":"${existingDocs['address_proof'] ?? ''}"}';

    // Update lead with document paths — also auto-advance stage if currently 'new' or 'contacted'
    await db.query(
      '''
      UPDATE leads 
      SET kyc_doc_path = @docPath,
          stage = CASE 
            WHEN stage IN ('new', 'contacted') THEN 'kyc_uploaded'
            ELSE stage
          END
      WHERE id = @id AND sales_person_id = @salesId
      ''',
      substitutionValues: {
        'docPath': docPathStr,
        'id': id,
        'salesId': user.id,
      },
    );

    return ApiResponse.success(
      message: 'Documents uploaded successfully',
      data: {
        'documents': existingDocs,
        'stage': 'kyc_uploaded',
      },
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}

/// Parse the stored doc path string (JSON) into a map.
Map<String, dynamic> _parseDocPaths(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      // Remove empty string values
      decoded.removeWhere(
        (key, value) => value == null || value.toString().isEmpty,
      );
      return decoded;
    }
    return {'raw': raw};
  } catch (_) {
    return {'raw': raw};
  }
}
