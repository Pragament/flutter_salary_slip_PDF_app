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

final employeeProvider = StateNotifierProvider<EmployeeNotifier, List<Employee>?>((ref) {
  final currentOrganization = ref.watch(currentOrganizationProvider);
  final currentBranch = ref.watch(currentBranchProvider);
  final currentGroup= ref.watch(currentGroupProvider);
  return EmployeeNotifier(ref.read(employeeRepositoryProvider),currentOrganization,currentBranch,currentGroup);
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

  EmployeeNotifier(this._employeeRepository,this.organization,this.branch,this.group) : super([]){
    init();
  }

  // Initialize the list of employees for a specific group
  void init()  {
    if (organization!=null && branch!=null && group!=null) {
      state = _employeeRepository.getAll(organization!.id, branch!.id, group!.id);
    }else{
      state=[];
    }
  }

  // Add a new employee to a group
  void addEmployee(String organizationId, String branchId, String groupId, Employee employee) {
    _employeeRepository.addEmployee(organizationId, branchId, groupId, employee);
    state = _employeeRepository.getAll(organizationId, branchId, groupId);
  }

  // Update an existing employee
  void updateEmployee(String organizationId, String branchId, String groupId, Employee employee) {
    _employeeRepository.updateEmployee(organizationId, branchId, groupId, employee);
    state = _employeeRepository.getAll(organizationId, branchId, groupId);
  }

  // Delete an employee from a group
  void deleteEmployee(String organizationId, String branchId, String groupId, String employeeId) {
    print(state.toString());
    _employeeRepository.deleteEmployee(organizationId, branchId, groupId, employeeId);
    state = _employeeRepository.getAll(organizationId, branchId, groupId);
    print(state.toString());
  }

  // Import employees from CSV data
 Future<void> importEmployeesFromCsvData(
  String orgId,
  String branchId,
  String groupId,
  List<Map<String, dynamic>> employeesData
) async {
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
}
}