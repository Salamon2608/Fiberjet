import 'package:postgres/postgres.dart';
import 'package:backend/config/env_config.dart';
void main() async {
  final conn = await Connection.open(Endpoint(host: EnvConfig.dbHost, port: EnvConfig.dbPort, database: EnvConfig.dbName, username: EnvConfig.dbUser, password: EnvConfig.dbPass), settings: const ConnectionSettings(sslMode: SslMode.disable));
  final result = await conn.execute('SELECT start_date, expiry_date FROM user_plans');
  for (var row in result) { print(row.toColumnMap()); }
  await conn.close();
}
