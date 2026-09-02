import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../routes/api/v1/customer/dashboard.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockUserModel extends Mock implements UserModel {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('GET /api/v1/customer/dashboard', () {
    late RequestContext context;
    late Request request;
    late PostgresService db;
    late UserModel user;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      db = _MockPostgresService();
      user = _MockUserModel();

      when(() => context.request).thenReturn(request);
      when(() => context.read<PostgresService>()).thenReturn(db);
      when(() => context.read<UserModel>()).thenReturn(user);
      when(() => user.id).thenReturn('user-123');
      when(() => user.toJson()).thenReturn({'id': 'user-123', 'name': 'John Doe', 'role': 'customer'});
    });

    test('responds with methodNotAllowed if method is not GET', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns dashboard data including active_ads when successful', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final mockPlansResult = _MockResult();
      when(() => mockPlansResult.isEmpty).thenReturn(true);
      when(() => mockPlansResult.isNotEmpty).thenReturn(false);

      final mockComplaintsResult = _MockResult();
      when(() => mockComplaintsResult.iterator).thenReturn(<ResultRow>[].iterator);
      when(() => mockComplaintsResult.map<Map<String, dynamic>>(any())).thenReturn([]);

      final mockRowAd = _MockResultRow();
      final adMap = {
        'id': 'ad-789',
        'title': 'Awesome Promotion',
        'is_active': true,
        'impressions': 5,
        'clicks': 1,
        'created_at': DateTime.utc(2026, 5, 20),
      };
      when(() => mockRowAd.toColumnMap()).thenReturn(adMap);

      final mockAdsResult = _MockResult();
      when(() => mockAdsResult.iterator).thenReturn([mockRowAd].iterator);
      when(() => mockAdsResult.map<Map<String, dynamic>>(any())).thenAnswer((invocation) {
        final f = invocation.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [f(mockRowAd)];
      });

      // Stub queries sequentially or check query content
      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((invocation) async {
        final queryStr = invocation.positionalArguments[0] as String;
        if (queryStr.contains('user_plans')) {
          return mockPlansResult;
        } else if (queryStr.contains('complaints')) {
          return mockComplaintsResult;
        }
        return mockAdsResult;
      });

      // Ads query doesn't pass substitutionValues, so we also stub query with 1 positional arg
      when(() => db.query(any())).thenAnswer((invocation) async {
        return mockAdsResult;
      });

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['data'], isA<Map<String, dynamic>>());
      expect(body['data']['user']['name'], equals('John Doe'));
      expect(body['data']['active_ads'], isA<List<dynamic>>());
      expect(body['data']['active_ads'].length, equals(1));
      expect(body['data']['active_ads'][0]['title'], equals('Awesome Promotion'));
      expect(body['data']['active_ads'][0]['impressions'], equals(5));
      expect(body['data']['active_ads'][0]['clicks'], equals(1));
    });
  });
}
