import 'dart:io';
import 'dart:math';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/customer/complaints  → List user's complaints (with optional status filter)
/// POST /api/v1/customer/complaints  → Create a new complaint/support ticket
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List complaints ───────────────────────────────────
  if (request.method == HttpMethod.get) {
    final statusFilter = request.url.queryParameters['status'];
    final page = int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
    final offset = (page - 1) * limit;

    String whereClause = 'WHERE c.user_id = @userId';
    final values = <String, dynamic>{
      'userId': user.id,
      'limit': limit,
      'offset': offset,
    };

    if (statusFilter != null && statusFilter.isNotEmpty) {
      whereClause += ' AND c.status = @status';
      values['status'] = statusFilter;
    }

    final result = await db.query(
      '''
      SELECT c.*, u.name as assigned_to_name
      FROM complaints c
      LEFT JOIN users u ON c.assigned_to = u.id
      $whereClause
      ORDER BY c.created_at DESC
      LIMIT @limit OFFSET @offset
      ''',
      substitutionValues: values,
    );

    // Get total count for pagination
    final countResult = await db.query(
      'SELECT COUNT(*) as total FROM complaints c $whereClause',
      substitutionValues: {
        'userId': user.id,
        if (statusFilter != null) 'status': statusFilter,
      },
    );

    final complaints = result.map((r) => r.toColumnMap()).toList();
    final total = countResult.first.toColumnMap()['total'] ?? 0;

    return ApiResponse.success(
      data: {
        'complaints': complaints,
        'total': total,
        'page': page,
        'limit': limit,
      },
    );
  }

  // ── POST: Create new complaint ─────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final title = body['title'] as String?;
    final category = body['category'] as String?;
    final description = body['description'] as String?;
    final latitude = body['latitude'] != null ? double.tryParse(body['latitude'].toString()) : null;
    final longitude = body['longitude'] != null ? double.tryParse(body['longitude'].toString()) : null;

    if (category == null || description == null) {
      return ApiResponse.error(
        message: 'category and description are required',
      );
    }

    // Generate secure 4-digit arrival OTP for in-app verification
    final randomOtp = (1000 + Random().nextInt(9000)).toString();

    final result = await db.query(
      '''
      INSERT INTO complaints (user_id, title, category, description, status, latitude, longitude, visit_otp)
      VALUES (@userId, @title, @category, @description, 'open', @latitude, @longitude, @visitOtp)
      RETURNING id, title, category, description, status, latitude, longitude, visit_otp, is_otp_verified, arrived_at, created_at
      ''',
      substitutionValues: {
        'userId': user.id,
        'title': title ?? 'Support Ticket',
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'visitOtp': randomOtp,
      },
    );

    final created = result.first.toColumnMap();

    return ApiResponse.success(
      message: 'Complaint submitted successfully',
      statusCode: HttpStatus.created,
      data: created,
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
