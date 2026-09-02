import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/tech/customers/:id → Detailed customer view
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;
  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  if (request.method == HttpMethod.put) {
    try {
      final body = await request.json() as Map<String, dynamic>;
      
      // Update customer user details
      final userUpdates = <String>[];
      final userSubs = <String, dynamic>{'userId': id};
      
      if (body.containsKey('name')) {
        userUpdates.add('name = @name');
        userSubs['name'] = body['name'];
      }
      if (body.containsKey('phone')) {
        userUpdates.add('phone = @phone');
        userSubs['phone'] = body['phone'];
      }
      if (body.containsKey('email')) {
        userUpdates.add('email = @email');
        userSubs['email'] = body['email'];
      }
      
      if (userUpdates.isNotEmpty) {
        await db.query(
          '''
          UPDATE users 
          SET ${userUpdates.join(', ')} 
          WHERE id = @userId
          ''',
          substitutionValues: userSubs,
        );
      }
      
      // Update or link modem_info details
      if (body.containsKey('modem_mac') || body.containsKey('modem_ip') || body.containsKey('modem_type')) {
        final modemCheck = await db.query(
          'SELECT id FROM modem_info WHERE user_id = @userId LIMIT 1',
          substitutionValues: {'userId': id},
        );
        
        if (modemCheck.isEmpty) {
          // Insert a new modem record
          await db.query(
            '''
            INSERT INTO modem_info (user_id, mac_address, device_type, ip_address, signal_strength, last_synced)
            VALUES (@userId, @mac, @type, @ip, -25, NOW())
            ''',
            substitutionValues: {
              'userId': id,
              'mac': body['modem_mac']?.toString() ?? '00:00:00:00:00:00',
              'type': body['modem_type']?.toString() ?? 'ONT Router',
              'ip': body['modem_ip']?.toString() ?? '192.168.1.1',
            },
          );
        } else {
          // Update the existing modem record
          final modemUpdates = <String>[];
          final modemSubs = <String, dynamic>{'userId': id};
          
          if (body.containsKey('modem_mac')) {
            modemUpdates.add('mac_address = @mac');
            modemSubs['mac'] = body['modem_mac'];
          }
          if (body.containsKey('modem_type')) {
            modemUpdates.add('device_type = @type');
            modemSubs['type'] = body['modem_type'];
          }
          if (body.containsKey('modem_ip')) {
            modemUpdates.add('ip_address = @ip');
            modemSubs['ip'] = body['modem_ip'];
          }
          
          if (modemUpdates.isNotEmpty) {
            await db.query(
              '''
              UPDATE modem_info 
              SET ${modemUpdates.join(', ')} 
              WHERE user_id = @userId
              ''',
              substitutionValues: modemSubs,
            );
          }
        }
      }
      
      return ApiResponse.success(message: 'Customer details updated successfully');
    } catch (e) {
      return ApiResponse.error(message: 'Failed to update customer details: $e');
    }
  }

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(message: 'Method not allowed', statusCode: HttpStatus.methodNotAllowed);
  }

  // 1. Customer profile + plan + modem
  final profileResult = await db.query(
    '''
    SELECT u.id, u.name, u.phone, u.email, u.status as account_status,
      u.location::text as location, u.created_at,
      p.name as plan_name, p.speed_mbps, p.price as plan_price, p.data_limit_gb,
      up.expiry_date, up.data_used_gb, up.status as plan_status, up.start_date,
      m.id as modem_id, m.signal_strength, m.ip_address as modem_ip,
      m.device_type as modem_type, m.mac_address as modem_mac, m.last_synced as modem_last_seen,
      CASE WHEN m.signal_strength > -100 AND m.signal_strength IS NOT NULL THEN 'online' ELSE 'offline' END as connection_status
    FROM users u
    LEFT JOIN user_plans up ON up.user_id = u.id AND up.status = 'active'
    LEFT JOIN plans p ON up.plan_id = p.id
    LEFT JOIN modem_info m ON m.user_id = u.id
    WHERE u.id = @customerId
    LIMIT 1
    ''',
    substitutionValues: {'customerId': id},
  );

  if (profileResult.isEmpty) {
    return ApiResponse.error(message: 'Customer not found', statusCode: HttpStatus.notFound);
  }

  final profile = profileResult.first.toColumnMap();

  // 2. Network devices
  final devicesResult = await db.query(
    '''
    SELECT id, mac_address, device_name, is_trusted, is_blocked, last_seen
    FROM network_devices WHERE user_id = @customerId ORDER BY last_seen DESC NULLS LAST
    ''',
    substitutionValues: {'customerId': id},
  );
  final devices = devicesResult.map((r) => r.toColumnMap()).toList();

  // 3. Recent tickets
  final ticketsResult = await db.query(
    '''
    SELECT id, title, category, status, created_at
    FROM complaints WHERE user_id = @customerId
    ORDER BY created_at DESC LIMIT 5
    ''',
    substitutionValues: {'customerId': id},
  );
  final tickets = ticketsResult.map((r) => r.toColumnMap()).toList();

  // 4. Job history with this tech
  final jobsResult = await db.query(
    '''
    SELECT id, type, status, scheduled_at, completed_at, address
    FROM jobs WHERE customer_id = @customerId AND technician_id = @techId
    ORDER BY scheduled_at DESC LIMIT 10
    ''',
    substitutionValues: {'customerId': id, 'techId': user.id},
  );
  final jobs = jobsResult.map((r) => r.toColumnMap()).toList();

  return ApiResponse.success(data: {
    'profile': profile,
    'network_devices': devices,
    'recent_tickets': tickets,
    'job_history': jobs,
  });
}
