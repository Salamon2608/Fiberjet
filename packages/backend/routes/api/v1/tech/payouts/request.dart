import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/tech/payouts/request → Request a payout
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
        message: 'Method not allowed',
        statusCode: HttpStatus.methodNotAllowed);
  }

  final body = await request.json() as Map<String, dynamic>;
  final amount = body['amount'];
  final bankAccount = body['bank_account'] as String?;
  final upiId = body['upi_id'] as String?;
  final aadhaar = body['aadhaar'] as String?;

  if (amount == null) {
    return ApiResponse.error(message: 'amount is required');
  }

  // At least one payout method must be provided
  if (bankAccount == null && upiId == null) {
    return ApiResponse.error(
        message: 'Either bank_account or upi_id is required');
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  final result = await db.query(
    '''
    INSERT INTO payouts (user_id, role, amount, bank_account, upi_id, aadhaar, status)
    VALUES (@userId, 'technician', @amount, @bank, @upi, @aadhaar, 'pending')
    RETURNING id, amount, status, created_at
    ''',
    substitutionValues: {
      'userId': user.id,
      'amount': amount,
      'bank': bankAccount,
      'upi': upiId,
      'aadhaar': aadhaar,
    },
  );

  return ApiResponse.success(
    message: 'Payout request submitted',
    statusCode: HttpStatus.created,
    data: result.first.toColumnMap(),
  );
}
