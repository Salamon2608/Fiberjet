import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/middleware/jwt_auth_guard.dart';
import 'package:backend/middleware/role_guard.dart';

Handler middleware(Handler handler) {
  return handler
      .use(roleGuard([Role.technician]))
      .use(jwtAuthGuard());
}
