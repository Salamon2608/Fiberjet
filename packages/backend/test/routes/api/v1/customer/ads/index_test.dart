import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../../routes/api/v1/customer/ads/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('GET /api/v1/customer/ads', () {
    late RequestContext context;
    late Request request;
    late PostgresService db;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      db = _MockPostgresService();

      when(() => context.request).thenReturn(request);
      when(() => context.read<PostgresService>()).thenReturn(db);
    });

    test('responds with methodNotAllowed if method is not GET', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('returns empty list of ads successfully', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      
      final mockResult = _MockResult();
      when(() => mockResult.iterator).thenReturn(<ResultRow>[].iterator);
      when(() => mockResult.map<Map<String, dynamic>>(any())).thenReturn([]);
      
      when(() => db.query(any())).thenAnswer((_) async => mockResult);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body, isA<Map<String, dynamic>>());
      expect(body['success'], isTrue);
      expect(body['data']['ads'], isEmpty);
    });

    test('returns list of ads when database query succeeds', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final mockRow = _MockResultRow();
      final adMap = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'title': 'Test Ad',
        'is_active': true,
        'impressions': 100,
        'clicks': 10,
        'created_at': DateTime.utc(2026, 1, 1),
      };
      
      when(() => mockRow.toColumnMap()).thenReturn(adMap);
      
      final mockResult = _MockResult();
      when(() => mockResult.iterator).thenReturn([mockRow].iterator);
      when(() => mockResult.map<Map<String, dynamic>>(any())).thenAnswer((invocation) {
        final f = invocation.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [f(mockRow)];
      });

      when(() => db.query(any())).thenAnswer((_) async => mockResult);

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['data']['ads'].length, equals(1));
      expect(body['data']['ads'][0]['title'], equals('Test Ad'));
      expect(body['data']['ads'][0]['impressions'], equals(100));
      expect(body['data']['ads'][0]['clicks'], equals(10));
    });

    test('responds with error when database query throws exception', () async {
      when(() => request.method).thenReturn(HttpMethod.get);
      when(() => db.query(any())).thenThrow(Exception('Database down'));

      final response = await route.onRequest(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], contains('Error fetching ads'));
    });
  });
}
