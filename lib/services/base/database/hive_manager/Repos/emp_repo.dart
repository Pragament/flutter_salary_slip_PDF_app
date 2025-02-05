
import 'package:hive_flutter/adapters.dart';

import '../models.dart';

class EmployeeRepository {
  final Box<Organization> _box;

  EmployeeRepository(this._box);

  // Get all employees in a group of a branch
  List<Employee>? getAll(String organizationId, String branchId, String groupId) {
    var organization = _box.get(organizationId);
    var branch = organization?.branches?.firstWhere((b) => b.id == branchId,);
    print("getAll");
    if (groupId=="allGroups"){
      List<Employee>? employees = branch?.groups
          ?.expand((group) => group.employees as List<Employee>)
          .toList();
      return employees;
    }else {

      var group = branch?.groups?.firstWhere((g) => g.id == groupId,);
      return group?.employees ?? [];
    }
  }

  // Add an employee to a group
  void addEmployee(String organizationId, String branchId, String groupId, Employee employee) {
    var box=Hive.box<Employee>("employees");
    box.add(employee);
    print(box.keys.toString());
    var organization = _box.get(organizationId);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      var group = branch?.groups?.firstWhere((g) => g.id == groupId);
      group?.employees?.add(employee);
      organization.save(); // Save the organization after adding the employee
    }
  }

  // Update an existing employee in a group
  void updateEmployee(String organizationId, String branchId, String groupId, Employee employee) {
    var organization = _box.get(organizationId);
    var box=Hive.box<Employee>("employees");
    print(box.keys.toString());
    final id=box.keys.firstWhere((key)=>box.get(key)?.id == employee.id);
    box.put(id,employee);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      var group = branch?.groups?.firstWhere((g) => g.id == groupId);
      var employeeIndex = group?.employees?.indexWhere((e) => e.id == employee.id);
      if (employeeIndex != -1) {
        group!.employees?[employeeIndex??0] = employee;
        organization.save(); // Save the updated organization
      }
    }
  }

  // Delete an employee from a group
  void deleteEmployee(String organizationId, String branchId, String groupId, String employeeId) {
    var empBox =  Hive.box<Employee>('employees');
    print(empBox.keys.toString());
    final id=empBox.keys.firstWhere((key)=>empBox.get(key)?.id == employeeId);
    var organization = _box.get(organizationId);
    if (organization != null) {
      var branch = organization.branches?.firstWhere((b) => b.id == branchId);
      var group = branch?.groups?.firstWhere((g) => g.id == groupId);
      group?.employees?.removeWhere((e) => e.id == employeeId);
      organization.save(); // Save the organization after deleting the employee
    }
    empBox.delete(id);
    print("deletion done");
  }

  // Find an employee by its ID
  Employee? getEmployeeById(String organizationId, String branchId, String groupId, String employeeId) {
    var organization = _box.get(organizationId);
    var branch = organization?.branches?.firstWhere((b) => b.id == branchId,);
    var group = branch?.groups?.firstWhere((g) => g.id == groupId,);
    return group?.employees?.firstWhere((e) => e.id == employeeId, );
  }
}
