import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/pool → Fetch all unassigned claimable tasks:
/// 1. Unassigned Support tickets (complaints where assigned_to IS NULL and status = 'open' and category is technical)
/// 2. Unassigned Installation jobs (jobs where technician_id IS NULL, type = 'installation', status = 'pending')
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  try {
    // 1. Fetch unassigned complaints OR complaints assigned to me
    final complaintsResult = await db.query(
      '''
      SELECT c.*, u.name as customer_name, u.phone as customer_phone,
             u.location[0] as customer_lng, u.location[1] as customer_lat,
             COALESCE(u.address, (SELECT address FROM jobs WHERE customer_id = u.id AND address IS NOT NULL AND address != '' LIMIT 1), 'Expertisor Academy, Srirangam, Tiruchirappalli') as customer_address
      FROM complaints c
      JOIN users u ON c.user_id = u.id
      CROSS JOIN (SELECT location FROM users WHERE id = @techId) t
      WHERE (c.assigned_to IS NULL OR c.assigned_to = @techId)
        AND c.status IN ('open', 'in_progress')
        AND c.category IN ('Technical Support', 'Connection Speed', 'Equipment Issue')
        AND (t.location IS NULL OR u.location IS NULL OR (u.location <-> t.location) <= 0.27)
      ORDER BY c.created_at DESC
      ''',
      substitutionValues: {
        'techId': user.id,
      },
    );

    final complaints = complaintsResult.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'title': map['title'] ?? 'Support Ticket',
        'category': map['category'],
        'description': map['description'],
        'status': map['status'],
        'customer_name': map['customer_name'],
        'customer_phone': map['customer_phone'],
        'customer_lng': map['longitude'] != null ? double.tryParse(map['longitude'].toString()) : map['customer_lng'],
        'customer_lat': map['latitude'] != null ? double.tryParse(map['latitude'].toString()) : map['customer_lat'],
        'address': map['customer_address'],
        'created_at': map['created_at']?.toString(),
        'assigned_to': map['assigned_to'],
        'type': 'complaint',
      };
    }).toList();

    // 2. Fetch unassigned installation jobs OR jobs assigned to me
    final jobsResult = await db.query(
      '''
      SELECT j.*, u.name as customer_name, u.phone as customer_phone
      FROM jobs j
      JOIN users u ON j.customer_id = u.id
      WHERE (j.technician_id IS NULL OR j.technician_id = @techId)
        AND j.status = 'pending'
        AND j.type = 'installation'
      ORDER BY j.created_at DESC
      ''',
      substitutionValues: {
        'techId': user.id,
      },
    );

    final jobs = jobsResult.map((r) {
      final map = r.toColumnMap();
      return {
        'id': map['id'],
        'title': 'Installation Request',
        'category': map['type'],
        'description': 'New user broadband connection setup.',
        'status': map['status'],
        'customer_name': map['customer_name'],
        'customer_phone': map['customer_phone'],
        'address': map['address'],
        'scheduled_at': map['scheduled_at']?.toString(),
        'created_at': map['created_at']?.toString(),
        'assigned_to': map['technician_id'],
        'type': 'job',
      };
    }).toList();

    // Combine pool items
    final pool = [...jobs, ...complaints];
    // Sort pool by created_at descending
    pool.sort((a, b) {
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return ApiResponse.success(data: {'pool': pool});
  } catch (e) {
    return ApiResponse.error(message: 'Error fetching pool: $e');
  }
}
