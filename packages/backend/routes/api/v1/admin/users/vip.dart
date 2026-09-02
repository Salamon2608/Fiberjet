import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/postgres_service.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return Response.json(
      statusCode: HttpStatus.methodNotAllowed, 
      body: {'message': 'Method not allowed'},
    );
  }

  final body = await request.json() as Map<String, dynamic>;
  final userId = body['user_id'] as String?;
  final isVip = body['is_vip'] as bool?;

  if (userId == null || isVip == null) {
    return Response.json(
      statusCode: HttpStatus.badRequest, 
      body: {'message': 'Both user_id and is_vip (boolean) are required'},
    );
  }

  final db = context.read<PostgresService>();

  await db.query(
    '''
    UPDATE users 
    SET is_vip = @isVip 
    WHERE id = @userId
    ''',
    substitutionValues: {
      'isVip': isVip,
      'userId': userId,
    }
  );

  return Response.json(body: {'message': 'User VIP status updated successfully'});
}
