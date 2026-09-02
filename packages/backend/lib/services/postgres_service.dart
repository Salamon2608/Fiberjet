import 'package:backend/config/env_config.dart';
import 'package:postgres/postgres.dart';

class PostgresService {
  late final Pool _pool;

  PostgresService() {
    _pool = Pool.withEndpoints(
      [
        Endpoint(
          host: EnvConfig.dbHost,
          port: EnvConfig.dbPort,
          database: EnvConfig.dbName,
          username: EnvConfig.dbUser,
          password: EnvConfig.dbPass,
        )
      ],
      settings: PoolSettings(
        maxConnectionCount: 20,
        sslMode: SslMode.disable,
      ),
    );
  }

  /// Exposes the connection pool to execute queries.
  Pool get connection => _pool;
  
  /// Helper method for simple queries to avoid typing .connection.execute every time.
  Future<Result> query(String fmtString, {Map<String, dynamic>? substitutionValues}) async {
    if (substitutionValues != null) {
       return await _pool.execute(Sql.named(fmtString), parameters: substitutionValues);
    }
    return await _pool.execute(fmtString);
  }

  /// Helper to execute a transaction
  Future<T> withTransaction<T>(Future<T> Function(Session) callback) async {
    return await _pool.withConnection((connection) async {
      return await connection.runTx((tx) async {
        return await callback(tx);
      });
    });
  }

  /// Closes the connection pool gracefully.
  Future<void> dispose() async {
    await _pool.close();
  }
}
