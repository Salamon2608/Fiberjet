import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET  /api/v1/tech/modem/:customerId → Get customer's modem info
/// POST /api/v1/tech/modem/:customerId → Reboot customer's modem
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // ── GET: Modem info ───────────────────────────────────────
  if (request.method == HttpMethod.get) {
    final result = await db.query(
      '''
      SELECT m.*, u.name as customer_name
      FROM modem_info m
      JOIN users u ON m.user_id = u.id
      WHERE m.user_id = @customerId
      ORDER BY m.last_synced DESC NULLS LAST
      LIMIT 1
      ''',
      substitutionValues: {'customerId': id},
    );

    if (result.isEmpty) {
      return ApiResponse.success(data: null, message: 'No modem found for this customer');
    }

    final modem = result.first.toColumnMap();
    final signal = modem['signal_strength'] as int? ?? -100;

    String signalQuality;
    if (signal > -30) signalQuality = 'excellent';
    else if (signal > -50) signalQuality = 'very_good';
    else if (signal > -70) signalQuality = 'good';
    else if (signal > -85) signalQuality = 'weak';
    else signalQuality = 'critical';

    final isOnline = signal > -100;

    return ApiResponse.success(data: {
      'id': modem['id'],
      'customer_name': modem['customer_name'],
      'mac_address': modem['mac_address'],
      'device_type': modem['device_type'],
      'ip_address': modem['ip_address'],
      'signal_strength': signal,
      'signal_quality': signalQuality,
      'is_online': isOnline,
      'last_synced': modem['last_synced']?.toString(),
      'created_at': modem['created_at']?.toString(),
    });
  }

  // ── POST: Reboot modem ────────────────────────────────────
  if (request.method == HttpMethod.post) {
    // Set signal to -100 to simulate reboot (offline)
    final updateResult = await db.query(
      '''
      UPDATE modem_info SET signal_strength = -100, last_synced = NOW()
      WHERE user_id = @customerId
      RETURNING id
      ''',
      substitutionValues: {'customerId': id},
    );

    if (updateResult.isEmpty) {
      return ApiResponse.error(message: 'Modem not found for this customer', statusCode: HttpStatus.notFound);
    }

    // Log the reboot action
    try {
      await db.query(
        '''
        INSERT INTO audit_logs (user_id, action, target_table, target_id, new_values)
        VALUES (@techId, 'modem_reboot', 'modem_info', @modemId,
          jsonb_build_object('customer_id', @customerId, 'technician', @techName))
        ''',
        substitutionValues: {
          'techId': user.id,
          'modemId': updateResult.first.toColumnMap()['id'],
          'customerId': id,
          'techName': user.name,
        },
      );
    } catch (_) {}

    return ApiResponse.success(message: 'Reboot command sent. Device will restart in ~30 seconds.');
  }

  return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
}
