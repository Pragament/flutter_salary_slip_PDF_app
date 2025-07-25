
// Provider to access all employees within a group

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/services/providers/cur_group_provider.dart';
import 'package:hive_flutter/adapters.dart';

import '../base/database/hive_manager/Repos/emp_repo.dart';
import '../base/database/hive_manager/models.dart';
import '../base/id_generator.dart';
import 'cur_branch_provider.dart';
import 'cur_org_provider.dart';

final employeeProvider =
    StateNotifierProvider<EmployeeNotifier, List<Employee>?>((ref) {
  final currentOrganization = ref.watch(currentOrganizationProvider);
  final currentBranch = ref.watch(currentBranchProvider);
  final currentGroup = ref.watch(currentGroupProvider);
  return EmployeeNotifier(ref.read(employeeRepositoryProvider),
      currentOrganization, currentBranch, currentGroup);
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  final box = Hive.box<Organization>('organizations');
  return EmployeeRepository(box);
});

// StateNotifier to manage employees
class EmployeeNotifier extends StateNotifier<List<Employee>?> {
  final EmployeeRepository _employeeRepository;

  final Organization? organization;
  final Branch? branch;
  final Group? group;

  EmployeeNotifier(
      this._employeeRepository, this.organization, this.branch, this.group)
      : super(null) {
    loadEmployees();
  }

  // Load employees from repository
  Future<void> loadEmployees() async {
    if (organization != null && branch != null && group != null) {
      try {
        final employees =
            _employeeRepository.getAll(organization!.id, branch!.id, group!.id);
        state = employees;
        print(
            'Loaded ${employees?.length ?? 0} employees for group ${group!.name}');
      } catch (e) {
        print('Error loading employees: $e');
        // Keep the previous state if there's an error
        if (state == null) state = [];
      }
    } else {
      state = [];
    }
  }

  // Reload employees (can be called from UI when needed)
  Future<void> reloadEmployees() async {
    if (organization != null && branch != null && group != null) {
      try {
        final employees =
            _employeeRepository.getAll(organization!.id, branch!.id, group!.id);
        state = employees;
        print(
            'Reloaded ${employees?.length ?? 0} employees for group ${group!.name}');
      } catch (e) {
        print('Error reloading employees: $e');
        // Ensure we always have a non-null state
        if (state == null) state = [];
      }
    } else {
      state = [];
    }
  }

  // Add a new employee to a group
  void addEmployee(String organizationId, String branchId, String groupId,
      Employee employee) {
    try {
      _employeeRepository.addEmployee(
          organizationId, branchId, groupId, employee);
      // Reload the list after adding
      state = _employeeRepository.getAll(organizationId, branchId, groupId);
    } catch (e) {
      print('Error adding employee: $e');
      // Ensure error doesn't reset the state
      if (state == null) state = [];
    }
  }

  // Update an existing employee
  void updateEmployee(String organizationId, String branchId, String groupId,
      Employee employee) {
    try {
      _employeeRepository.updateEmployee(
          organizationId, branchId, groupId, employee);
      // Reload the list after updating
      state = _employeeRepository.getAll(organizationId, branchId, groupId);
    } catch (e) {
      print('Error updating employee: $e');
      // Ensure error doesn't reset the state
      if (state == null) state = [];
    }
  }

  // Delete an employee from a group
  void deleteEmployee(String organizationId, String branchId, String groupId,
      String employeeId) {
    try {
      print('Deleting employee $employeeId from group $groupId');
      _employeeRepository.deleteEmployee(
          organizationId, branchId, groupId, employeeId);
      // Reload the list after deleting
      state = _employeeRepository.getAll(organizationId, branchId, groupId);
      print('After deletion: ${state?.length ?? 0} employees remaining');
    } catch (e) {
      print('Error deleting employee: $e');
      // Ensure error doesn't reset the state
      if (state == null) state = [];
    }
  }

  // Import employees from CSV data
  Future<void> importEmployeesFromCsvData(String orgId, String branchId,
      String groupId, List<Map<String, dynamic>> employeesData) async {
    try {
      for (final data in employeesData) {
        // Extract core properties
        final name = data['name'] as String? ?? '';
        final phone = data['phone'] as String? ?? '';
        final email = data['email'] as String? ?? '';

        // Extract dynamic fields
        final dynamicFields = data['dynamicFields'] as Map<String, String>;

        // Format dynamic fields for storage - group all CSV fields under 'csvImported' category
        Map<String, Map<String, String>> formattedDynamicFields = {
          'csvImported': dynamicFields,
        };

        // Create a new employee
        final employee = Employee(
          name,
          phone,
          email,
          formattedDynamicFields,
          generateId(),
        );

        // Add the employee
        _employeeRepository.addEmployee(orgId, branchId, groupId, employee);
      }

      // Reload employees
      state = _employeeRepository.getAll(orgId, branchId, groupId);
    } catch (e) {
      print('Error importing employees from CSV: $e');
      // Ensure error doesn't reset the state
      if (state == null) state = [];
    }
  }
}
