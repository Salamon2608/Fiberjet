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
      SELECT u.id, u.name, u.email, u.phone
      FROM users u
      WHERE u.email IN ('customer@fiberjet.com', 'salamon@gmail.com')
    ''');

    for (final uRow in result) {
      final userId = uRow[0];
      final name = uRow[1];
      final email = uRow[2];
      final phone = uRow[3];
      print('\n=======================================');
      print('User: $name | Email: $email | Phone: $phone | ID: $userId');
      
      final plansResult = await conn.execute(
        Sql.named('''
          SELECT up.id, up.plan_id, up.status, up.data_used_gb,
                 up.start_date, up.expiry_date,
                 p.name as plan_name, p.speed_mbps, p.price, 
                 p.data_limit_gb, p.cloud_storage_gb, p.ott_benefits
          FROM user_plans up
          JOIN plans p ON up.plan_id = p.id
          WHERE up.user_id = @userId
        '''),
        parameters: {'userId': userId},
      );
      
      if (plansResult.isEmpty) {
        print('  No plans subscribed.');
      } else {
        print('  Subscribed plans:');
        for (final pRow in plansResult) {
          final map = pRow.toColumnMap();
          print('    - Plan Name: ${map['plan_name']}');
          print('      Price: ${map['price']} | Speed: ${map['speed_mbps']} Mbps');
          print('      Status: ${map['status']}');
          print('      Data: ${map['data_used_gb']} / ${map['data_limit_gb']} GB');
          print('      Start: ${map['start_date']} | Expiry: ${map['expiry_date']}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    await conn.close();
  }
}
