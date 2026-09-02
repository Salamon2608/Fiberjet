import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/jobs/:id/status → Update status (enRoute, arrived, completed, etc.)
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final status = body['status'] as String?;

  if (status == null || status.isEmpty) {
    return ApiResponse.error(message: 'status is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Use a transaction if completing a job to update completed_at
  String updateClause = 'status = @status';
  if (status == 'completed') {
    updateClause += ', completed_at = NOW()';
  } else if (status == 'en_route') {
    updateClause += ', en_route_at = NOW()';
  } else if (status == 'arrived') {
    final otp = body['otp'] as String?;
    if (otp == null || otp.trim().isEmpty) {
      return ApiResponse.error(
        message: 'Arrival OTP is required. Please ask the customer for the verification code on their FiberJet app.',
        statusCode: HttpStatus.badRequest,
      );
    }

    final jobCheck = await db.query(
      'SELECT visit_otp FROM jobs WHERE id = @id LIMIT 1',
      substitutionValues: {'id': id},
    );
    if (jobCheck.isEmpty) {
      return ApiResponse.error(message: 'Job not found', statusCode: HttpStatus.notFound);
    }
    final expectedOtp = jobCheck.first.toColumnMap()['visit_otp']?.toString().trim();
    if (expectedOtp != null && expectedOtp.isNotEmpty && expectedOtp != otp.trim()) {
      return ApiResponse.error(
        message: 'Invalid arrival OTP. Please check the code shown on the customer\'s screen.',
        statusCode: HttpStatus.badRequest,
      );
    }

    updateClause += ', arrived_at = NOW(), is_otp_verified = TRUE';
  } else if (status == 'in_progress') {
    updateClause += ', in_progress_at = NOW()';
  }

  final result = await db.query(
    '''
    UPDATE jobs 
    SET $updateClause
    WHERE id = @id AND technician_id = @techId
    RETURNING *
    ''',
    substitutionValues: {
      'id': id,
      'techId': user.id,
      'status': status,
    },
  );

  if (result.isEmpty) {
    return ApiResponse.error(message: 'Job not found', statusCode: HttpStatus.notFound);
  }

  final jobRow = result.first.toColumnMap();

  if (status == 'completed' && jobRow['type'] == 'installation') {
    try {
      final customerResult = await db.query(
        'SELECT phone FROM users WHERE id = @customerId LIMIT 1',
        substitutionValues: {'customerId': jobRow['customer_id']},
      );
      if (customerResult.isNotEmpty) {
        final customerPhone = customerResult.first.toColumnMap()['phone'] as String;
        await db.query(
          "UPDATE leads SET stage = 'installed' WHERE phone = @phone",
          substitutionValues: {'phone': customerPhone},
        );
      }

      // Link the modem if MAC address is provided by the technician
      final macAddress = body['mac_address'] as String?;
      if (macAddress != null && macAddress.trim().isNotEmpty) {
        // Delete any existing modem info for this customer to ensure clean replacement
        await db.query(
          'DELETE FROM modem_info WHERE user_id = @userId',
          substitutionValues: {'userId': jobRow['customer_id']},
        );
        
        await db.query(
          '''
          INSERT INTO modem_info (user_id, mac_address, device_type, ip_address, signal_strength, last_synced)
          VALUES (@userId, @mac, @type, @ip, -25, NOW())
          ''',
          substitutionValues: {
            'userId': jobRow['customer_id'],
            'mac': macAddress.trim(),
            'type': 'ONT Router',
            'ip': '192.168.1.1',
          },
        );
      }
    } catch (e) {
      print('Failed to complete installation setup: $e');
    }
  }

  // Insert audit log on successful status update
  try {
    await db.query(
      '''
      INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
      VALUES (@techId, 'update_job_status', 'jobs', @jobId,
        jsonb_build_object('technician_name', @techName, 'status', @status))
      ''',
      substitutionValues: {
        'techId': user.id,
        'jobId': id,
        'techName': user.name,
        'status': status,
      },
    );
  } catch (_) {}

  return ApiResponse.success(
    message: 'Job status updated to $status',
    data: result.first.toColumnMap(),
  );
}
