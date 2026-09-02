import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fiberjet/theme/app_theme.dart';
import 'package:fiberjet/services/auth_provider.dart';
import 'package:fiberjet/screens/auth/splash_screen.dart';
import 'package:fiberjet/screens/auth/login_screen.dart';
import 'package:fiberjet/screens/customer/customer_main_screen.dart';
import 'package:fiberjet/screens/admin/admin_main_screen.dart';
import 'package:fiberjet/screens/sales/sales_main_screen.dart';
import 'package:fiberjet/screens/technician/tech_main_screen.dart';
import 'package:fiberjet/screens/auth/onboarding_screen.dart';

import 'package:fiberjet/services/customer_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
      ],
      child: const FiberJetApp(),
    ),
  );
}

class FiberJetApp extends StatefulWidget {
  const FiberJetApp({super.key});

  @override
  State<FiberJetApp> createState() => _FiberJetAppState();

  /// Navigate to the correct home screen based on user role
  static Widget getHomeForRole(String? role) {
    switch (role) {
      case 'customer':
        return const CustomerMainScreen();
      case 'sales':
        return const SalesMainScreen();
      case 'technician':
        return const TechMainScreen();
      case 'admin':
        return const AdminMainScreen();
      default:
        return const LoginScreen();
    }
  }
}

class _FiberJetAppState extends State<FiberJetApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiber Jet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminMainScreen(),
        '/customer': (context) => const CustomerMainScreen(),
        '/sales': (context) => const SalesMainScreen(),
        '/technician': (context) => const TechMainScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
      },
    );
  }
}
