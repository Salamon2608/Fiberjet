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
    final result = await conn.execute('SELECT * FROM plans');
    print('\nAll Available Plans in Database:');
    for (final row in result) {
      final map = row.toColumnMap();
      print('=======================================');
      print('ID: ${map['id']}');
      print('Name: ${map['name']}');
      print('Speed: ${map['speed_mbps']} Mbps | Price: ${map['price']}');
      print('Data Limit: ${map['data_limit_gb']} GB | Storage: ${map['cloud_storage_gb']} GB');
      print('OTT Benefits: ${map['ott_benefits']}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await conn.close();
  }
}
