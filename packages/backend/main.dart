import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:backend/services/hardware_simulator_service.dart';

import 'package:backend/services/postgres_service.dart';

Future<HttpServer> run(Handler handler, InternetAddress ip, int port) async {
  // Start the hardware simulator securely in the background
  HardwareSimulatorService.start();

  // Start the web server
  return serve(handler, ip, port);
}
