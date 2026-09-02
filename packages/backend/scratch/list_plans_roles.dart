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
    print('=== COMMISSIONS COLUMNS ===');
    final commsColResult = await conn.execute("SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'commissions'");
    for (final row in commsColResult) {
      print(row.toColumnMap());
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await conn.close();
  }
}
