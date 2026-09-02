import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/plans/buy
/// Body: { "plan_id": "uuid" }
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  try {
    final body = await context.request.json() as Map<String, dynamic>;
    final planId = body['plan_id'] as String?;

    if (planId == null) {
      return ApiResponse.error(message: 'plan_id is required');
    }

    // Verify plan exists
    final planCheck = await db.query(
      'SELECT validity_days, data_limit_gb FROM plans WHERE id = @planId AND is_active = true LIMIT 1',
      substitutionValues: {'planId': planId},
    );

    if (planCheck.isEmpty) {
      return ApiResponse.error(message: 'Plan not found or inactive', statusCode: 404);
    }

    final planRow = planCheck.first.toColumnMap();
    final validityDays = planRow['validity_days'] ?? 30;

    // Check if there is an active plan
    final activeCheck = await db.query(
      "SELECT id, expiry_date FROM user_plans WHERE user_id = @userId AND status = 'active' LIMIT 1",
      substitutionValues: {'userId': user.id},
    );

    String status = 'active';
    dynamic startDate = 'NOW()';
    dynamic expiryDate = "NOW() + INTERVAL '$validityDays days'";

    if (activeCheck.isNotEmpty) {
      status = 'queued';
      final activeRow = activeCheck.first.toColumnMap();
      final activeExpiry = activeRow['expiry_date'];
      
      await db.query(
        '''
        INSERT INTO user_plans (user_id, plan_id, status, start_date, expiry_date)
        VALUES (@userId, @planId, @status, @startDate::TIMESTAMPTZ, @startDate::TIMESTAMPTZ + INTERVAL '$validityDays days')
        ''',
        substitutionValues: {
          'userId': user.id,
          'planId': planId,
          'status': status,
          'startDate': activeExpiry,
        },
      );
    } else {
      await db.query(
        '''
        INSERT INTO user_plans (user_id, plan_id, status, start_date, expiry_date)
        VALUES (@userId, @planId, @status, NOW(), NOW() + INTERVAL '$validityDays days')
        ''',
        substitutionValues: {
          'userId': user.id,
          'planId': planId,
          'status': status,
        },
      );
    }

    // Transaction intentionally omitted since 'transactions' table does not exist.

    return ApiResponse.success(
      message: status == 'active' 
          ? 'Plan purchased and activated successfully!' 
          : 'Plan purchased and queued for next cycle!',
    );
  } catch (e) {
    return ApiResponse.error(message: 'Failed to buy plan: $e');
  }
}
