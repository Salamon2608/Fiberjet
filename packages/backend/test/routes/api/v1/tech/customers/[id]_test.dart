import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:postgres/postgres.dart';
import 'package:fiberjet_shared/fiberjet_shared.dart';
import 'package:backend/services/postgres_service.dart';
import '../../../../../../routes/api/v1/tech/customers/[id].dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}
class _MockPostgresService extends Mock implements PostgresService {}
class _MockUserModel extends Mock implements UserModel {}
class _MockResult extends Mock implements Result {}
class _MockResultRow extends Mock implements ResultRow {}

void main() {
  group('Customer Detail Route /api/v1/tech/customers/:id', () {
    late RequestContext context;
    late Request request;
    late PostgresService db;
    late UserModel techUser;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      db = _MockPostgresService();
      techUser = _MockUserModel();

      when(() => context.request).thenReturn(request);
      when(() => context.read<PostgresService>()).thenReturn(db);
      when(() => context.read<UserModel>()).thenReturn(techUser);
      when(() => techUser.id).thenReturn('tech-123');
    });

    test('responds with error if method is not GET or PUT', () async {
      when(() => request.method).thenReturn(HttpMethod.post);

      final response = await route.onRequest(context, 'cust-456');

      expect(response.statusCode, equals(HttpStatus.methodNotAllowed));
      final body = await response.json();
      expect(body['success'], isFalse);
      expect(body['message'], equals('Method not allowed'));
    });

    test('GET returns customer detailed profile, devices, tickets, jobs', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final mockProfileRow = _MockResultRow();
      when(() => mockProfileRow.toColumnMap()).thenReturn({
        'id': 'cust-456',
        'name': 'Customer Name',
        'phone': '1234567890',
        'email': 'customer@test.com',
        'account_status': 'active',
        'location': 'POINT(12.971598 77.594562)',
        'created_at': DateTime.utc(2026, 5, 20),
        'plan_name': 'FiberJet Starter',
        'speed_mbps': 50,
        'plan_price': 499,
        'data_limit_gb': 1000,
        'expiry_date': DateTime.utc(2026, 6, 20),
        'data_used_gb': 120.5,
        'plan_status': 'active',
        'start_date': DateTime.utc(2026, 5, 20),
        'modem_id': 'modem-789',
        'signal_strength': -35,
        'modem_ip': '192.168.1.1',
        'modem_type': 'ONT Router',
        'modem_mac': 'AA:BB:CC:DD:EE:FF',
        'modem_last_seen': DateTime.utc(2026, 6, 1),
        'connection_status': 'online',
      });

      final mockProfileResult = _MockResult();
      when(() => mockProfileResult.isEmpty).thenReturn(false);
      when(() => mockProfileResult.isNotEmpty).thenReturn(true);
      when(() => mockProfileResult.first).thenReturn(mockProfileRow);

      final mockDeviceRow = _MockResultRow();
      when(() => mockDeviceRow.toColumnMap()).thenReturn({
        'id': 'device-999',
        'mac_address': '11:22:33:44:55:66',
        'device_name': 'My Laptop',
        'is_trusted': true,
        'is_blocked': false,
        'last_seen': DateTime.utc(2026, 6, 2),
      });

      final mockDevicesResult = _MockResult();
      when(() => mockDevicesResult.map<Map<String, dynamic>>(any())).thenAnswer((inv) {
        final fn = inv.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [fn(mockDeviceRow)];
      });

      final mockTicketRow = _MockResultRow();
      when(() => mockTicketRow.toColumnMap()).thenReturn({
        'id': 'ticket-1',
        'title': 'No Internet',
        'category': 'technical',
        'status': 'open',
        'created_at': DateTime.utc(2026, 6, 2),
      });

      final mockTicketsResult = _MockResult();
      when(() => mockTicketsResult.map<Map<String, dynamic>>(any())).thenAnswer((inv) {
        final fn = inv.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [fn(mockTicketRow)];
      });

      final mockJobRow = _MockResultRow();
      when(() => mockJobRow.toColumnMap()).thenReturn({
        'id': 'job-1',
        'type': 'installation',
        'status': 'completed',
        'scheduled_at': DateTime.utc(2026, 5, 20),
        'completed_at': DateTime.utc(2026, 5, 20),
        'address': 'Test Address',
      });

      final mockJobsResult = _MockResult();
      when(() => mockJobsResult.map<Map<String, dynamic>>(any())).thenAnswer((inv) {
        final fn = inv.positionalArguments[0] as Map<String, dynamic> Function(ResultRow);
        return [fn(mockJobRow)];
      });

      when(() => db.query(
        any(),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((invocation) async {
        final queryStr = invocation.positionalArguments[0] as String;
        if (queryStr.contains('LEFT JOIN user_plans')) {
          return mockProfileResult;
        } else if (queryStr.contains('network_devices')) {
          return mockDevicesResult;
        } else if (queryStr.contains('complaints')) {
          return mockTicketsResult;
        } else if (queryStr.contains('jobs')) {
          return mockJobsResult;
        }
        return _MockResult();
      });

      final response = await route.onRequest(context, 'cust-456');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['data'], isA<Map<String, dynamic>>());
      
      final profile = body['data']['profile'];
      expect(profile['name'], equals('Customer Name'));
      expect(profile['modem_mac'], equals('AA:BB:CC:DD:EE:FF'));

      final devices = body['data']['network_devices'];
      expect(devices, isA<List>());
      expect(devices.length, equals(1));
      expect(devices[0]['device_name'], equals('My Laptop'));

      final tickets = body['data']['recent_tickets'];
      expect(tickets, isA<List>());
      expect(tickets.length, equals(1));
      expect(tickets[0]['title'], equals('No Internet'));
    });

    test('PUT updates customer user profile and inserts new modem if not exists', () async {
      when(() => request.method).thenReturn(HttpMethod.put);
      when(() => request.json()).thenAnswer((_) async => {
        'name': 'Updated Name',
        'phone': '9876543210',
        'email': 'updated@test.com',
        'modem_mac': 'FF:EE:DD:CC:BB:AA',
        'modem_ip': '192.168.1.100',
        'modem_type': 'ONT Router Premium',
      });

      // Stub user update query
      when(() => db.query(
        any(that: contains('UPDATE users')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      // Stub modem check query to return empty (no existing modem)
      final emptyModemCheck = _MockResult();
      when(() => emptyModemCheck.isEmpty).thenReturn(true);
      when(() => emptyModemCheck.isNotEmpty).thenReturn(false);
      when(() => db.query(
        any(that: contains('SELECT id FROM modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => emptyModemCheck);

      // Stub modem insert query
      when(() => db.query(
        any(that: contains('INSERT INTO modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      final response = await route.onRequest(context, 'cust-456');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['message'], equals('Customer details updated successfully'));

      // Verify users table was updated
      verify(() => db.query(
        any(that: contains('UPDATE users')),
        substitutionValues: any(named: 'substitutionValues'),
      )).called(1);

      // Verify modem_info insert was called
      verify(() => db.query(
        any(that: contains('INSERT INTO modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).called(1);
    });

    test('PUT updates customer user profile and updates existing modem details', () async {
      when(() => request.method).thenReturn(HttpMethod.put);
      when(() => request.json()).thenAnswer((_) async => {
        'name': 'Updated Name',
        'phone': '9876543210',
        'email': 'updated@test.com',
        'modem_mac': 'FF:EE:DD:CC:BB:AA',
        'modem_ip': '192.168.1.100',
        'modem_type': 'ONT Router Premium',
      });

      // Stub user update query
      when(() => db.query(
        any(that: contains('UPDATE users')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      // Stub modem check query to return non-empty (has existing modem)
      final existingModemRow = _MockResultRow();
      when(() => existingModemRow.toColumnMap()).thenReturn({'id': 'modem-789'});
      
      final existingModemCheck = _MockResult();
      when(() => existingModemCheck.isEmpty).thenReturn(false);
      when(() => existingModemCheck.isNotEmpty).thenReturn(true);
      when(() => existingModemCheck.first).thenReturn(existingModemRow);

      when(() => db.query(
        any(that: contains('SELECT id FROM modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => existingModemCheck);

      // Stub modem update query
      when(() => db.query(
        any(that: contains('UPDATE modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).thenAnswer((_) async => _MockResult());

      final response = await route.onRequest(context, 'cust-456');

      expect(response.statusCode, equals(HttpStatus.ok));
      final body = await response.json();
      expect(body['success'], isTrue);
      expect(body['message'], equals('Customer details updated successfully'));

      // Verify users table was updated
      verify(() => db.query(
        any(that: contains('UPDATE users')),
        substitutionValues: any(named: 'substitutionValues'),
      )).called(1);

      // Verify modem_info update was called
      verify(() => db.query(
        any(that: contains('UPDATE modem_info')),
        substitutionValues: any(named: 'substitutionValues'),
      )).called(1);
    });
  });
}
