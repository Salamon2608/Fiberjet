import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/sales/complaints  → List billing/sales-related complaints
/// POST /api/v1/sales/complaints  → Update a complaint's status with resolution note
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List billing-related complaints ─────────────────────
  if (request.method == HttpMethod.get) {
    final statusFilter = request.url.queryParameters['status'];

    String whereClause = '''
      WHERE (c.assigned_to = @salesId OR (c.assigned_to IS NULL AND c.category = 'Billing & Accounts'))
    ''';
    final values = <String, dynamic>{'salesId': user.id};

    if (statusFilter != null && statusFilter.isNotEmpty) {
      whereClause += ' AND c.status = @status';
      values['status'] = statusFilter;
    }

    final result = await db.query(
      '''
      SELECT c.*, 
             cu.name as customer_name, cu.phone as customer_phone,
             cu.location[0] as customer_lng, cu.location[1] as customer_lat,
             COALESCE(cu.address, (SELECT address FROM jobs WHERE customer_id = cu.id AND address IS NOT NULL AND address != '' LIMIT 1), 'Expertisor Academy, Srirangam, Tiruchirappalli') as customer_address,
             t.name as assigned_to_name
      FROM complaints c
      LEFT JOIN users cu ON c.user_id = cu.id
      LEFT JOIN users t ON c.assigned_to = t.id
      $whereClause
      ORDER BY 
        CASE WHEN c.status = 'open' THEN 0
             WHEN c.status = 'in_progress' THEN 1
             WHEN c.status = 'rejected' THEN 2
             ELSE 3 END,
        c.created_at DESC
      ''',
      substitutionValues: values,
    );

    final complaints = result.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'title': map['title'],
        'category': map['category'],
        'description': map['description'],
        'status': map['status'],
        'resolution_note': map['resolution'],
        'customer_name': map['customer_name'],
        'customer_phone': map['customer_phone'],
        'customer_lng': map['customer_lng'],
        'customer_lat': map['customer_lat'],
        'customer_address': map['customer_address'],
        'assigned_to': map['assigned_to'],
        'assigned_to_name': map['assigned_to_name'],
        'created_at': map['created_at']?.toString(),
        'updated_at': map['updated_at']?.toString(),
      };
    }).toList();

    return ApiResponse.success(data: complaints);
  }

  // ── POST: Update complaint status ────────────────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final complaintId = body['complaint_id'] as String?;
    final status = body['status'] as String?;
    final resolutionNote = body['resolution_note'] as String?;

    if (complaintId == null || status == null) {
      return ApiResponse.error(
        message: 'complaint_id and status are required',
      );
    }

    final validStatuses = ['in_progress', 'resolved', 'rejected'];
    if (!validStatuses.contains(status)) {
      return ApiResponse.error(
        message: 'Status must be one of: ${validStatuses.join(', ')}',
      );
    }

    final updates = <String>[
      'status = @status',
      'updated_at = NOW()',
      "assigned_to = COALESCE(assigned_to, @salesId)",
    ];
    final params = <String, dynamic>{
      'complaintId': complaintId,
      'status': status,
      'salesId': user.id,
    };

    if (resolutionNote != null && resolutionNote.isNotEmpty) {
      updates.add('resolution = @note');
      params['note'] = resolutionNote;
    }

    await db.query(
      '''
      UPDATE complaints
      SET ${updates.join(', ')}
      WHERE id = @complaintId
      ''',
      substitutionValues: params,
    );

    return ApiResponse.success(
      message: 'Complaint updated to $status',
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
