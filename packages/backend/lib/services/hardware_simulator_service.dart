import 'dart:async';
import 'dart:math';
import 'package:postgres/postgres.dart';
import 'package:backend/config/env_config.dart';

class HardwareSimulatorService {
  static bool _isRunning = false;
  static Timer? _timer;

  static void start() async {
    if (_isRunning) return;
    _isRunning = true;

    print('Starting Built-in Hardware Simulator...');

    final endpoint = Endpoint(
      host: EnvConfig.dbHost,
      port: EnvConfig.dbPort,
      database: EnvConfig.dbName,
      username: EnvConfig.dbUser,
      password: EnvConfig.dbPass,
    );

    try {
      final connection = await Connection.open(
        endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable),
      );
      print('Hardware Simulator Connected to database.');

      final random = Random();

      _timer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        try {
          final result = await connection.execute('SELECT id, signal_strength FROM modem_info');
          
          if (result.isEmpty) return;

          print('Simulating heartbeat for ${result.length} modems at ${DateTime.now()}');

          for (final row in result) {
            final id = row[0];
            int currentSignal = row[1] as int? ?? -25;
            if (currentSignal <= -90) {
              // Device is rebooting, bring it back online!
              currentSignal = -25;
            } else {
              // Fluctuate normally
              currentSignal += random.nextInt(5) - 2;
              currentSignal = currentSignal.clamp(-40, -10).toInt();
            }

            await connection.execute(
              Sql.named('UPDATE modem_info SET signal_strength = @signal, last_synced = NOW() WHERE id = @id'),
              parameters: {
                'signal': currentSignal,
                'id': id,
              },
            );
          }
        } catch (e) {
          print('Error during simulation loop: $e');
        }
      });
    } catch (e) {
      print('Failed to start Hardware Simulator: $e');
      _isRunning = false;
    }
  }

  static void stop() {
    _timer?.cancel();
    _isRunning = false;
  }
}
