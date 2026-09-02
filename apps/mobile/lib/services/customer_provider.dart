import 'package:flutter/material.dart';
import 'package:fiberjet/services/customer_data_service.dart';

/// Manages the state for the customer dashboard and related features.
class CustomerProvider extends ChangeNotifier {
  bool _isLoading = false;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get dashboardData => _dashboardData;
  String? get errorMessage => _errorMessage;

  /// Fetch dashboard data from the backend.
  Future<void> fetchDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await CustomerDataService.getDashboardData();

    if (result.success && result.data != null) {
      _dashboardData = result.data as Map<String, dynamic>;
    } else {
      _errorMessage = result.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear dashboard data (e.g., on logout).
  void clear() {
    _dashboardData = null;
    _errorMessage = null;
    notifyListeners();
  }
}
