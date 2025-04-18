import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../csv/employee_csv_service.dart';

final csvServiceProvider = Provider<EmployeeCsvService>((ref) {
  return EmployeeCsvService();
});