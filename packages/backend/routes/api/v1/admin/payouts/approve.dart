import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/admin/payouts/approve → List pending payouts
/// POST /api/v1/admin/payouts/approve → Approve or reject a payout
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  // ── GET: List pending payouts with user details ──────────
  if (request.method == HttpMethod.get) {
    final db = context.read<PostgresService>();
    final params = request.url.queryParameters;
    final statusFilter = params['status'] ?? 'pending';
    final role = params['role'];

    final conditions = <String>['1=1'];
    final values = <String, dynamic>{};

    if (statusFilter.isNotEmpty) {
      conditions.add('p.status = @status');
      values['status'] = statusFilter;
    }

    if (role != null && role.isNotEmpty) {
      conditions.add('p.role = @role');
      values['role'] = role;
    }

    final whereClause = conditions.join(' AND ');

    try {
      final result = await db.query(
        '''
        SELECT p.id, p.user_id, p.role, p.amount, p.bank_account, p.upi_id, 
               p.status, p.created_at,
               u.name as user_name, u.phone as user_phone
        FROM payouts p
        JOIN users u ON p.user_id = u.id
        WHERE $whereClause
        ORDER BY p.created_at DESC
        ''',
        substitutionValues: values,
      );

      // Fetch fraud indicators: Check for multiple pending requests or duplicate bank accounts
      final fraudCheck = await db.query('''
        SELECT user_id, COUNT(id) as pending_count 
        FROM payouts WHERE status = 'pending' GROUP BY user_id HAVING COUNT(id) > 5
      ''');
      
      final duplicateBanks = await db.query('''
        SELECT bank_account, COUNT(DISTINCT user_id) as users_with_same_bank
        FROM payouts WHERE bank_account IS NOT NULL GROUP BY bank_account HAVING COUNT(DISTINCT user_id) > 1
      ''');
      
      final highVolumeUsers = fraudCheck.map((r) => r.toColumnMap()['user_id']).toSet();
      final duplicateBankAccounts = duplicateBanks.map((r) => r.toColumnMap()['bank_account']).toSet();

      final payouts = result.map((r) {
        final row = r.toColumnMap();
        final List<String> fraudFlags = [];
        
        if (highVolumeUsers.contains(row['user_id'])) {
          fraudFlags.add('Suspicious Velocity: High volume of pending requests');
        }
        if (row['bank_account'] != null && duplicateBankAccounts.contains(row['bank_account'])) {
          fraudFlags.add('Duplicate Account: Bank account used by multiple users');
        }

        return <String, dynamic>{
          'fraud_flags': fraudFlags,
          for (final entry in row.entries)
            entry.key: entry.value is DateTime
                ? (entry.value as DateTime).toIso8601String()
                : entry.value is bool || entry.value is int || entry.value is double || entry.value == null
                    ? entry.value
                    : entry.value.toString(),
        };
      }).toList();

      // Summary stats
      final summaryResult = await db.query('''
        SELECT 
          COUNT(*) as total_pending,
          COALESCE(SUM(amount), 0) as total_amount
        FROM payouts
        WHERE status = 'pending'
      ''');

      final summary = summaryResult.first.toColumnMap();

      return ApiResponse.success(data: {
        'payouts': payouts,
        'summary': {
          'total_pending': summary['total_pending'] ?? 0,
          'total_amount': summary['total_amount']?.toString() ?? '0',
        },
      });
    } catch (e) {
      return ApiResponse.error(message: 'Failed to fetch payouts: $e');
    }
  }

  // ── POST: Approve or reject a payout ─────────────────────
  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final payoutId = body['payout_id'] as String?;
  // Accept both 'action' (frontend) and 'status' (legacy) keys
  final action = body['action'] as String? ?? body['status'] as String?;

  if (payoutId == null || action == null) {
    return ApiResponse.error(message: 'payout_id and action are required');
  }

  // Normalize: frontend sends 'approve'/'reject', DB needs 'approved'/'rejected'
  String dbStatus;
  if (action == 'approve' || action == 'approved') {
    dbStatus = 'approved';
  } else if (action == 'reject' || action == 'rejected') {
    dbStatus = 'rejected';
  } else {
    return ApiResponse.error(message: 'Invalid action. Use "approve" or "reject".');
  }

  final admin = context.read<UserModel>();
  final db = context.read<PostgresService>();

  try {
    final result = await db.query(
      '''
      UPDATE payouts 
      SET status = @status, approved_by = @adminId 
      WHERE id = @payoutId
      RETURNING id, status, amount
      ''',
      substitutionValues: {
        'status': dbStatus,
        'adminId': admin.id,
        'payoutId': payoutId,
      },
    );

    if (result.isEmpty) {
      return ApiResponse.error(message: 'Payout not found', statusCode: HttpStatus.notFound);
    }

    return ApiResponse.success(
      message: 'Payout $dbStatus successfully',
      data: {
        'id': result.first.toColumnMap()['id']?.toString(),
        'status': dbStatus,
      },
    );
  } catch (e) {
    return ApiResponse.error(message: 'Failed to update payout: $e');
  }
}
