import 'dart:io';

class EnvConfig {
  static final Map<String, String> _env = Platform.environment;

  // Database Configuration
  static String get dbHost => _env['DB_HOST'] ?? 'localhost';
  static int get dbPort => int.tryParse(_env['DB_PORT'] ?? '5432') ?? 5432;
  static String get dbName => _env['DB_NAME'] ?? 'fiberjet';
  static String get dbUser => _env['DB_USER'] ?? 'postgres';
  static String get dbPass => _env['DB_PASS'] ?? 'salo'; // Defaulting to your current password

  // Auth Configuration
  static String get jwtSecret => _env['JWT_SECRET'] ?? 'SUPER_SECRET_FIBERJET_KEY_123!@#';
  
  // Storage Configuration
  static String get storagePath => _env['STORAGE_PATH'] ?? 'storage_files';

  // Server Configuration
  static int get port => int.tryParse(_env['PORT'] ?? '8080') ?? 8080;
}
