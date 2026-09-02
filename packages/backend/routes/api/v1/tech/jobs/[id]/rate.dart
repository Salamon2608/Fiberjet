import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/jobs/:id/rate → Submit customer rating
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final stars = body['stars'] as int?;
  final comment = body['comment'] as String?;

  if (stars == null || stars < 1 || stars > 5) {
    return ApiResponse.error(message: 'stars (1-5) is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Get the job to find the customer
  final jobResult = await db.query(
    'SELECT customer_id FROM jobs WHERE id = @id AND technician_id = @techId LIMIT 1',
    substitutionValues: {'id': id, 'techId': user.id},
  );

  if (jobResult.isEmpty) {
    return ApiResponse.error(
        message: 'Job not found', statusCode: HttpStatus.notFound);
  }

  final customerId = jobResult.first.toColumnMap()['customer_id'];

  // Insert rating
  final result = await db.query(
    '''
    INSERT INTO ratings (job_id, customer_id, technician_id, stars, comment)
    VALUES (@jobId, @customerId, @techId, @stars, @comment)
    RETURNING id, stars, comment, created_at
    ''',
    substitutionValues: {
      'jobId': id,
      'customerId': customerId,
      'techId': user.id,
      'stars': stars,
      'comment': comment ?? '',
    },
  );

  return ApiResponse.success(
    message: 'Rating submitted successfully',
    statusCode: HttpStatus.created,
    data: result.first.toColumnMap(),
  );
}
