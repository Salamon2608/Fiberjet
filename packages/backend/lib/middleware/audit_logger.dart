import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';

/// Middleware that logs POST, PUT, DELETE actions into the audit_logs table.
Middleware auditLogger() {
  return (handler) {
    return (context) async {
      // 1. Process the request (wait for the response)
      final response = await handler(context);

      final request = context.request;
      final method = request.method.value;

      // 2. We only want to log mutations (POST, PUT, DELETE, PATCH)
      if (method == 'POST' || method == 'PUT' || method == 'DELETE' || method == 'PATCH') {
        try {
          // 3. Try to extract the user if they are authenticated.
          // Since the user is provided by jwtAuthGuard, we need to read it.
          // Dart Frog throws a StateError if the provider is not found.
          UserModel? user;
          try {
            user = context.read<UserModel>();
          } catch (_) {
            // Not authenticated, user remains null
          }

          final db = context.read<PostgresService>();
          final path = request.url.path;
          
          // Determine the target table from the path
          String targetTable = 'unknown';
          if (path.contains('/users')) targetTable = 'users';
          else if (path.contains('/sales-persons')) targetTable = 'sales_persons';
          else if (path.contains('/technicians')) targetTable = 'technicians';
          else if (path.contains('/jobs')) targetTable = 'jobs';
          else if (path.contains('/leads')) targetTable = 'leads';
          else if (path.contains('/plans')) targetTable = 'plans';
          else if (path.contains('/complaints')) targetTable = 'complaints';
          else if (path.contains('/payouts')) targetTable = 'payouts';
          else if (path.contains('/ads')) targetTable = 'ads';
          else if (path.contains('/speed_test')) targetTable = 'speed_tests';
          else if (path.contains('/network_devices')) targetTable = 'network_devices';
          else if (path.contains('/cloud_drive')) targetTable = 'cloud_files';

          final ipAddress = request.connectionInfo.remoteAddress.address;
          final userAgent = request.headers['user-agent'] ?? 'Unknown';

          // Insert into audit_logs
          await db.query(
            '''
            INSERT INTO audit_logs 
            (user_id, action, target_table, ip_address) 
            VALUES (@user_id, @action, @target_table, @ip_address)
            ''',
            substitutionValues: {
              'user_id': user?.id,
              'action': '$method $path',
              'target_table': targetTable,
              'ip_address': ipAddress,
            },
          );
        } catch (e) {
          // Fire and forget, we don't want audit logging failures to crash the app response
          print('Audit Log Error: $e');
        }
      }

      return response;
    };
  };
}
