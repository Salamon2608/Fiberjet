import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import 'package:backend/utils/api_response.dart';

/// GET /api/v1/customer/ott_claims
/// Lists available OTT platforms from the user's active plan + their claimed status.
Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.get) {
    return ApiResponse.error(
      message: 'Method not allowed',
      statusCode: HttpStatus.methodNotAllowed,
    );
  }

  final user = context.read<UserModel>();
  final db = context.read<PostgresService>();

  // Get the user's active plan with OTT benefits
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
    return ApiResponse.success(
      data: {
        'available': [],
        'claimed': [],
        'message': 'No active plan found',
      },
    );
  }

  final ottBenefits = planResult.first.toColumnMap()['ott_benefits'];

  // Parse JSONB — could be a List of platform names
  List<String> availablePlatforms = [];
  if (ottBenefits is List) {
    availablePlatforms = ottBenefits.cast<String>();
  } else if (ottBenefits is Map) {
    availablePlatforms = ottBenefits.keys.cast<String>().toList();
  }

  // Get user's existing claims
  final claimsResult = await db.query(
    '''
    SELECT * FROM ott_claims
    WHERE user_id = @userId
    ORDER BY claimed_at DESC
    ''',
    substitutionValues: {'userId': user.id},
  );

  final claims = claimsResult.map((r) => r.toColumnMap()).toList();
  final claimedPlatforms = claims.map((c) => c['ott_platform']).toSet();

  // Build the combined view
  final ottList = availablePlatforms.map((platform) {
    final claim = claims.firstWhere(
      (c) => c['ott_platform'] == platform,
      orElse: () => {},
    );

    return {
      'platform': platform,
      'is_claimed': claimedPlatforms.contains(platform),
      'status': claim.isNotEmpty ? claim['status'] : 'available',
      'claimed_at': claim.isNotEmpty ? claim['claimed_at']?.toString() : null,
      'expiry_date': claim.isNotEmpty ? claim['expiry_date']?.toString() : null,
    };
  }).toList();

  return ApiResponse.success(
    data: {
      'ott_benefits': ottList,
      'total_available': availablePlatforms.length,
      'total_claimed': claimedPlatforms.length,
    },
  );
}
