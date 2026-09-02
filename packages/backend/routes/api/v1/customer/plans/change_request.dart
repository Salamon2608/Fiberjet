import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/plans/change_request
/// Body: { "target_plan_id": "uuid", "reason": "Need more speed" }
///
/// GET /api/v1/customer/plans/change_request
/// Returns the user's pending/past plan change requests.
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: List user's plan change requests ──────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT pcr.*, p.name as target_plan_name, p.speed_mbps, p.price
      FROM plan_change_requests pcr
      JOIN plans p ON pcr.target_plan_id = p.id
      WHERE pcr.user_id = @userId
      ORDER BY pcr.created_at DESC
      ''',
      substitutionValues: {'userId': user.id},
    );

    final requests = result.map((r) => r.toColumnMap()).toList();
    return ApiResponse.success(data: {'requests': requests});
  }

  // ── POST: Submit a new plan change request ─────────────────
  if (request.method == HttpMethod.post) {
    final body = await request.json() as Map<String, dynamic>;
    final targetPlanId = body['target_plan_id'] as String?;
    final reason = body['reason'] as String?;

    if (targetPlanId == null) {
      return ApiResponse.error(message: 'target_plan_id is required');
    }

    // Verify target plan exists and is active
    final planCheck = await db.query(
      'SELECT id, name FROM plans WHERE id = @planId AND is_active = true LIMIT 1',
      substitutionValues: {'planId': targetPlanId},
    );

    if (planCheck.isEmpty) {
      return ApiResponse.error(
        message: 'Target plan not found or is inactive',
        statusCode: HttpStatus.notFound,
      );
    }

    // Check for existing pending request
    final pendingCheck = await db.query(
      "SELECT id FROM plan_change_requests WHERE user_id = @userId AND status = 'pending' LIMIT 1",
      substitutionValues: {'userId': user.id},
    );

    if (pendingCheck.isNotEmpty) {
      return ApiResponse.error(
        message: 'You already have a pending plan change request',
        statusCode: HttpStatus.conflict,
      );
    }

    // Get current plan
    final currentPlan = await db.query(
      "SELECT plan_id FROM user_plans WHERE user_id = @userId AND status = 'active' LIMIT 1",
      substitutionValues: {'userId': user.id},
    );

    final currentPlanId = currentPlan.isNotEmpty
        ? currentPlan.first.toColumnMap()['plan_id'] as String?
        : null;

    await db.query(
      '''
      INSERT INTO plan_change_requests (user_id, current_plan_id, target_plan_id, reason, status)
      VALUES (@userId, @currentPlanId, @targetPlanId, @reason, 'pending')
      ''',
      substitutionValues: {
        'userId': user.id,
        'currentPlanId': currentPlanId,
        'targetPlanId': targetPlanId,
        'reason': reason ?? '',
      },
    );

    return ApiResponse.success(
      message: 'Plan change request submitted successfully',
      statusCode: HttpStatus.created,
    );
  }

  return ApiResponse.error(
    message: 'Method not allowed',
    statusCode: HttpStatus.methodNotAllowed,
  );
}
