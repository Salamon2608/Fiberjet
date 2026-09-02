import 'dart:io';

import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';
import 'package:backend/utils/auth_helper.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:postgres/postgres.dart';

/// POST /api/v1/admin/payouts/bulk_approve
/// Body: { "payout_ids": ["uuid1", "uuid2"] }
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final (user, authError) = await AuthHelper.authenticate(context);
  if (user == null) return authError!;

  if (user.role != Role.admin) {
    return ApiResponse.error(
      message: 'Forbidden',
      statusCode: HttpStatus.forbidden,
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final payoutIds = body['payout_ids'] as List<dynamic>?;

  if (payoutIds == null || payoutIds.isEmpty) {
    return ApiResponse.error(message: 'payout_ids array is required');
  }

  final db = context.read<PostgresService>();

  // Ensure they are strictly strings
  final validIds = payoutIds.map((e) => e.toString()).toList();

  try {
    await db.withTransaction((tx) async {
      for (final id in validIds) {
        await tx.execute(
          Sql.named('''
            UPDATE payouts 
            SET status = 'approved', approved_by = @adminId 
            WHERE id = @payoutId AND status = 'pending'
          '''),
          parameters: {
            'adminId': user.id,
            'payoutId': id,
          },
        );
      }
      return null;
    });

    return ApiResponse.success(
      message: 'Successfully approved ${validIds.length} payouts',
    );
  } catch (e) {
    return ApiResponse.error(message: 'Bulk approval failed: $e');
  }
}
