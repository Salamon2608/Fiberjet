import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// POST /api/v1/customer/ott_claims/:id/claim
/// Claims an OTT benefit. The :id here is the platform name (e.g., "netflix").
Future<Response> onRequest(RequestContext context, String id) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();
  final platform = id;

  // Verify the user has an active plan with this OTT benefit
  final planResult = await db.query(
    '''
    SELECT p.ott_benefits
    FROM user_plans up
    JOIN plans p ON up.plan_id = p.id
    WHERE up.user_id = @userId AND up.status = 'active'
    LIMIT 1
    ''',
    substitutionValues: {'userId': user.id},
  );

  if (planResult.isEmpty) {
    return ApiResponse.error(
      message: 'No active plan found',
      statusCode: HttpStatus.forbidden,
    );
  }

  final ottBenefits = planResult.first.toColumnMap()['ott_benefits'];
  List<String> availablePlatforms = [];
  if (ottBenefits is List) {
    availablePlatforms = ottBenefits.cast<String>();
  } else if (ottBenefits is Map) {
    availablePlatforms = ottBenefits.keys.cast<String>().toList();
  }

  if (!availablePlatforms.map((p) => p.toLowerCase()).contains(platform.toLowerCase())) {
    return ApiResponse.error(
      message: 'This OTT platform is not included in your plan',
      statusCode: HttpStatus.forbidden,
    );
  }

  // Check if already claimed
  final existingClaim = await db.query(
    '''
    SELECT id FROM ott_claims
    WHERE user_id = @userId AND LOWER(ott_platform) = LOWER(@platform) AND status = 'active'
    LIMIT 1
    ''',
    substitutionValues: {
      'userId': user.id,
      'platform': platform,
    },
  );

  if (existingClaim.isNotEmpty) {
    return ApiResponse.error(
      message: 'You have already claimed this OTT benefit',
      statusCode: HttpStatus.conflict,
    );
  }

  // Create the claim — expires in 30 days by default
  final expiryDate = DateTime.now().add(const Duration(days: 30));

  final result = await db.query(
    '''
    INSERT INTO ott_claims (user_id, ott_platform, status, expiry_date)
    VALUES (@userId, @platform, 'active', @expiryDate)
    RETURNING id, ott_platform, status, claimed_at, expiry_date
    ''',
    substitutionValues: {
      'userId': user.id,
      'platform': platform,
      'expiryDate': expiryDate,
    },
  );

  return ApiResponse.success(
    message: '$platform claimed successfully!',
    statusCode: HttpStatus.created,
    data: result.first.toColumnMap(),
  );
}
