import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/middleware/jwt_auth_guard.dart';
import 'package:backend/middleware/role_guard.dart';

Handler middleware(Handler handler) {
  // `use` applies middlewares from right to left (bottom to top conceptually)
  // so jwtAuthGuard() will intercept the request first, inject UserModel,
  // and then roleGuard will intercept it and verify the user rule.
  return handler
      .use(roleGuard([Role.customer]))
      .use(jwtAuthGuard());
}
