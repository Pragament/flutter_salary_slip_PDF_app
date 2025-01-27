import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/base/id_generator.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../../../services/providers/emp_provider.dart';

class ManageEmployeesScreen extends ConsumerStatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  ConsumerState<ManageEmployeesScreen> createState() => _ManageBranchesScreenState();
}

class _ManageBranchesScreenState extends ConsumerState<ManageEmployeesScreen> {

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final currentBranch = ref.watch(currentBranchProvider);
    final currentOrg = ref.watch(currentOrganizationProvider);
    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Manage Employees")),
        body: Center(child: Text("No group selected.")),
      );
    }

    final employees = ref.watch(employeeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Employees - ${currentGroup.name}"),
      ),
      body: (employees==null || employees.isEmpty)?Center(child: Text("No Employees.")):ListView.builder(
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final employee = employees[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              color: Colors.grey.shade100,
              child: ListTile(
                title: Text(employee.name),
                subtitle: Text(employee.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () =>context.push("/create-edit-emp",
                          extra: {
                        "title":"Edit Employee",
                                'initialName': employee.name,
                                'initialPhone': employee.phone,
                                'initialEmail': employee.email,
                                'initialDynamicFields': employee.dynamicFields,
                        'onSave':(name, phone, email, fields) {
                                final updatedEmployee = Employee(
                                    name, phone, email, fields, employee.id);
                                ref.read(employeeProvider.notifier).updateEmployee(
                                    currentOrg!.id,
                                    currentBranch!.id,
                                    currentGroup.id,
                                    updatedEmployee);
                              },
                            })
                          // _openCreateEditDialog(
                          //   context,
                          //   groupId: currentGroup.id,
                          //   employee: employee,
                          //   onSave: (name, phone, email, fields) {
                          //     final updatedEmployee =
                          //     Employee(name, phone, email, fields, employee.id);
                          //     ref
                          //         .read(employeeProvider.notifier)
                          //         .updateEmployee(currentOrg!.id, currentBranch!.id,
                          //         currentGroup.id, updatedEmployee);
                          //   },
                          // ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () =>
                          ref
                              .read(employeeProvider.notifier)
                              .deleteEmployee(
                              currentOrg!.id, currentBranch!.id, currentGroup.id,
                              employee.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>context.push("/create-edit-emp",extra: {
          "title":"Create Employee",
          'initialName': null,
          'initialPhone': null,
          'initialEmail': null,
          'initialDynamicFields': null,
            "onSave": (name, phone, email, fields) {
              final newEmployee = Employee(
                  name, phone, email, fields, generateId());
              ref.read(employeeProvider.notifier).addEmployee(
                  currentOrg!.id, currentBranch!.id, currentGroup.id,
                  newEmployee);
            },
        }),
            // _openCreateEditDialog(
            //   context,
            //   groupId: currentGroup.id,
            //   onSave: (name, phone, email, fields) {
            //     final newEmployee = Employee(
            //         name, phone, email, fields, generateId());
            //     ref.read(employeeProvider.notifier).addEmployee(
            //         currentOrg!.id, currentBranch!.id, currentGroup.id,
            //         newEmployee);
            //   },
            // ),
        child: Icon(Icons.add),
      ),
    );
  }
  //
  // void _openCreateEditDialog(BuildContext context,
  //     {required String groupId,
  //       Employee? employee,
  //       required void Function(
  //           String name, String phone, String email, Map<String, String> fields)
  //       onSave}) {
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return CreateEditEmployeePage(
  //         title: employee == null ? "Create Employee" : "Edit Employee",
  //         initialName: employee?.name,
  //         initialPhone: employee?.phone,
  //         initialEmail: employee?.email,
  //         initialDynamicFields: employee?.dynamicFields,
  //         onSubmit: onSave,
  //       );
  //     },
  //   );
  // }
}