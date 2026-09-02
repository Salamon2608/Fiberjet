import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';

/// Middleware that restricts route access to specific roles.
/// Assumes [jwtAuthGuard] has already injected [UserModel] into the context.
Middleware roleGuard(List<Role> allowedRoles) {
  return (handler) {
    return (context) async {
      // Pull the authenticated user from the context
      final user = context.read<UserModel>();

      // Admin has override access usually, but we keep it explicit.
      // If we want admin to bypass everything, we can add `|| user.role == Role.admin`.
      if (!allowedRoles.contains(user.role)) {
        return Response.json(
          statusCode: 403,
          body: {'error': 'Forbidden. Your role has insufficient permissions.'},
        );
      }

      return handler(context);
    };
  };
}
