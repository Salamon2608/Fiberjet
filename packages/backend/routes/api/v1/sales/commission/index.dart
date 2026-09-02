import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/sales/commission → Summary and history of commissions
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // 1. Get Commission History
  final commissionsResult = await db.query(
    '''
    SELECT c.*, l.customer_name 
    FROM commissions c
    LEFT JOIN leads l ON c.lead_id = l.id
    WHERE c.sales_person_id = @userId
    ORDER BY c.created_at DESC
    ''',
    substitutionValues: {'userId': user.id},
  );

  final commissions = commissionsResult.map((r) => r.toColumnMap()).toList();

  // 2. Calculate Stats
  final statsResult = await db.query(
    '''
    SELECT 
      SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) as pending_amount,
      SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) as total_paid
    FROM commissions
    WHERE sales_person_id = @userId
    ''',
    substitutionValues: {'userId': user.id},
  );

  final stats = statsResult.first.toColumnMap();

  return ApiResponse.success(
    data: {
      'commissions': commissions,
      'stats': {
        'pending_amount': stats['pending_amount'] ?? 0,
        'total_paid': stats['total_paid'] ?? 0,
      }
    },
  );
}
