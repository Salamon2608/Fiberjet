import 'package:backend/config/env_config.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class AuthService {
  static String get _jwtSecret => EnvConfig.jwtSecret;

  /// Hashes a plaintext password using bcrypt.
  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verifies a plaintext password against a stored bcrypt hash.
  bool verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }

  /// Generates a valid JSON Web Token for the user.
  String generateToken(String userId, String roleName) {
    final jwt = JWT({
      'user_id': userId,
      'role': roleName,
      // Token expires in 7 days
      'exp': DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000,
    });
    
    return jwt.sign(SecretKey(_jwtSecret));
  }

  /// Verifies the token and returns the payload.
  JWT? verifyToken(String token) {
    try {
      // Verify signature and expiration
      return JWT.verify(token, SecretKey(_jwtSecret));
    } catch (e) {
      return null;
    }
  }
}
