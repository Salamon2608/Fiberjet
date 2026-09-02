import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// Technical categories that route to technicians
const _techCategories = [
  'Technical Support',
  'Connection Speed',
  'Equipment Issue',
];

/// GET  /api/v1/tech/complaints  → List technical complaints (assigned to me + unassigned)
/// POST /api/v1/tech/complaints  → Update a complaint's status with resolution note
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List complaints ─────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final statusFilter = request.url.queryParameters['status'];

    String whereClause = '''
      WHERE (c.assigned_to = @techId OR (
        c.assigned_to IS NULL 
        AND c.category IN ('Technical Support', 'Connection Speed', 'Equipment Issue')
        AND (tech.location IS NULL OR cu.location IS NULL OR (cu.location <-> tech.location) <= 0.27)
      ))
    ''';
    final values = <String, dynamic>{'techId': user.id};

    if (statusFilter != null && statusFilter.isNotEmpty) {
      whereClause += ' AND c.status = @status';
      values['status'] = statusFilter;
    }

    final result = await db.query(
      '''
      SELECT c.*, 
             cu.name as customer_name, cu.phone as customer_phone,
             cu.location[0] as customer_lng, cu.location[1] as customer_lat,
             COALESCE(cu.address, (SELECT address FROM jobs WHERE customer_id = cu.id AND address IS NOT NULL AND address != '' LIMIT 1), 'Customer Premises') as customer_address,
             t.name as assigned_to_name
      FROM complaints c
      LEFT JOIN users cu ON c.user_id = cu.id
      LEFT JOIN users t ON c.assigned_to = t.id
      CROSS JOIN (SELECT location FROM users WHERE id = @techId) tech
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
        'customer_lng': map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : map['customer_lng'],
        'customer_lat': map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : map['customer_lat'],
        'customer_address': map['customer_address'],
        'assigned_to': map['assigned_to'],
        'assigned_to_name': map['assigned_to_name'],
        'is_otp_verified': map['is_otp_verified'] ?? false,
        'arrived_at': map['arrived_at']?.toString(),
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

    // Validate status
    final validStatuses = ['in_progress', 'resolved', 'rejected'];
    if (!validStatuses.contains(status)) {
      return ApiResponse.error(
        message: 'Status must be one of: ${validStatuses.join(', ')}',
      );
    }

    // Check if complaint is already assigned to a different technician
    final existingCheck = await db.query(
      'SELECT assigned_to FROM complaints WHERE id = @complaintId LIMIT 1',
      substitutionValues: {'complaintId': complaintId},
    );
    if (existingCheck.isEmpty) {
      return ApiResponse.error(message: 'Ticket not found', statusCode: HttpStatus.notFound);
    }
    final currentAssigned = existingCheck.first.toColumnMap()['assigned_to'] as String?;
    if (currentAssigned != null && currentAssigned != user.id) {
      return ApiResponse.error(
        message: 'This support ticket is already assigned to another technician.',
        statusCode: HttpStatus.conflict,
      );
    }

    // Assign to self when picking up a ticket
    final updates = <String>[
      'status = @status',
      'updated_at = NOW()',
    ];
    final params = <String, dynamic>{
      'complaintId': complaintId,
      'status': status,
      'techId': user.id,
    };

    // Auto-assign to self if not already assigned
    updates.add(
      "assigned_to = COALESCE(assigned_to, @techId)",
    );

    if (resolutionNote != null && resolutionNote.isNotEmpty) {
      updates.add('resolution = @note');
      params['note'] = resolutionNote;
    }

    final updateResult = await db.query(
      '''
      UPDATE complaints
      SET ${updates.join(', ')}
      WHERE id = @complaintId
      RETURNING id
      ''',
      substitutionValues: params,
    );

    if (updateResult.isNotEmpty) {
      // Insert audit log on successful status update
      try {
        await db.query(
          '''
          INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
          VALUES (@techId, 'update_complaint_status', 'complaints', @complaintId,
            jsonb_build_object('technician_name', @techName, 'status', @status, 'resolution_note', @note))
          ''',
          substitutionValues: {
            'techId': user.id,
            'complaintId': complaintId,
            'techName': user.name,
            'status': status,
            'note': resolutionNote ?? '',
          },
        );
      } catch (_) {}
    }

    return ApiResponse.success(
      message: 'Complaint updated to $status',
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
