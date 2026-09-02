import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../../../routes/api/v1/customer/ads/[id]/impression.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('POST /api/v1/customer/ads/:id/impression', () {
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

    test('responds with methodNotAllowed if method is not POST', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final response = await route.onRequest(context, 'ad-123');

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
    });

    test('records impression successfully when ad exists', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final mockRow = _MockResultRow();
      final adMap = {
        'id': 'ad-123',
        'title': 'Impression Ad',
        'impressions': 43,
      };

      when(() => mockRow.toColumnMap()).thenReturn(adMap);

      final mockResult = _MockResult();
      when(() => mockResult.isEmpty).thenReturn(false);
      when(() => mockResult.first).thenReturn(mockRow);

      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => mockResult);

      final response = await route.onRequest(context, 'ad-123');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['message'], equals('Impression recorded successfully'));
      expect(body['data']['id'], equals('ad-123'));
      expect(body['data']['impressions'], equals(43));
    });

    test('responds with notFound if ad campaign does not exist', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final mockResult = _MockResult();
      when(() => mockResult.isEmpty).thenReturn(true);

      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => mockResult);

      final response = await route.onRequest(context, 'ad-999');

      expect(response.statusCode, equals(HttpStatus.notFound));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], equals('Ad campaign not found'));
    });

    test('responds with error when database update throws exception', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenThrow(Exception('DB Error'));

      final response = await route.onRequest(context, 'ad-123');

      expect(response.statusCode, equals(HttpStatus.badRequest));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], contains('Error recording impression'));
    });
  });
}
