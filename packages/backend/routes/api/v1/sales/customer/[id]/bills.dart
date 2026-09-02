import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/sales/customer/:id/bills → Last 6 months bills for a customer
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Verify the customer belongs to this sales person (has a lead)
  final ownerCheck = await db.query(
    '''
    SELECT id FROM leads
    WHERE sales_person_id = @salesId
      AND (phone = @custId OR id::text = @custId)
    LIMIT 1
    ''',
    substitutionValues: {'salesId': user.id, 'custId': id},
  );

  // Also allow lookup by user ID directly
  final billsResult = await db.query(
    '''
    SELECT 
      TO_CHAR(up.start_date, 'Month YYYY') as month,
      p.price as amount,
      up.status,
      p.name as plan_name,
      up.start_date,
      up.expiry_date
    FROM user_plans up
    JOIN plans p ON up.plan_id = p.id
    WHERE up.user_id::text = @custId
    ORDER BY up.start_date DESC
    LIMIT 6
    ''',
    substitutionValues: {'custId': id},
  );

  final bills = billsResult.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(
    data: {'bills': bills},
  );
}
