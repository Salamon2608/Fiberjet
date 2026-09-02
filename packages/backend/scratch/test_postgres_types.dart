import 'package:postgres/postgres.dart';
import 'package:backend/config/env_config.dart';

void main() async {
  final conn = await Connection.open(
    Endpoint(
      host: EnvConfig.dbHost,
      port: EnvConfig.dbPort,
      database: EnvConfig.dbName,
      username: EnvConfig.dbUser,
      password: EnvConfig.dbPass,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    final result = await conn.execute('''
      SELECT up.start_date, up.expiry_date, p.data_limit_gb, up.data_used_gb
      FROM user_plans up
      JOIN plans p ON up.plan_id = p.id
      WHERE up.status = 'active'
      LIMIT 1
    ''');
    
    if (result.isNotEmpty) {
      final row = result.first.toColumnMap();
      for (final entry in row.entries) {
        print('${entry.key}: ${entry.value} | Type: ${entry.value.runtimeType}');
      }
    } else {
      print('No active user plans found!');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await conn.close();
  }
}
