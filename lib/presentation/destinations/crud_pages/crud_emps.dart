import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/base/id_generator.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../../../services/providers/emp_provider.dart';
import '../../../services/csv/employee_csv_service.dart';
import '../../../services/providers/csv_service_provider.dart';

class ManageEmployeesScreen extends ConsumerStatefulWidget {
  const ManageEmployeesScreen({super.key});

  @override
  ConsumerState<ManageEmployeesScreen> createState() => _ManageBranchesScreenState();
}

class _ManageBranchesScreenState extends ConsumerState<ManageEmployeesScreen> {

  // Function to show prominent message
  void _showMessage(String message, bool isSuccess) {
    // Clear any existing SnackBars first
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Show the new SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final currentBranch = ref.watch(currentBranchProvider);
    final currentOrg = ref.watch(currentOrganizationProvider);
    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(title: Text("manageEmp".tr())),
        body: Center(child: Text("noGrpSelected".tr())),
      );
    }

    final employees = ref.watch(employeeProvider);
    print(employees?.isEmpty);


    return Scaffold(
      appBar: AppBar(
        title: Text("${"manageEmp".tr()} - ${currentGroup.name}"),
      ),
      body: (employees==null || employees.isEmpty)?Center(child: Text("noEmp".tr())):ListView.builder(
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final employee = employees[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 3,
              color: Colors.grey.shade100,
              child: ListTile(
                title: Text(employee.name,style: TextStyle(color: Colors.black)),
                subtitle: Text(employee.email,style: TextStyle(color: Colors.black)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () =>context.push("/create-edit-emp",
                          extra: {
                        "title":"editEmp".tr(),
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
                            }),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        // Delete the employee
                        ref
                            .read(employeeProvider.notifier)
                            .deleteEmployee(
                            currentOrg!.id, currentBranch!.id, currentGroup.id,
                            employee.id);
                        
                        // Show success message
                        _showMessage('Employee deleted successfully', false);
                        
                        // Force UI refresh
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // CSV Import button
          FloatingActionButton(
            heroTag: 'import_csv',
            onPressed: _importEmployeesFromCsv,
            tooltip: 'Import from CSV',
            child: const Icon(Icons.upload_file),
          ),
          const SizedBox(height: 16),
          // Add employee button
          FloatingActionButton(
            heroTag: 'add_employee',
            onPressed: () => context.push("/create-edit-emp", extra: {
              "title": "createEmp".tr(),
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
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
  
  Future<void> _importEmployeesFromCsv() async {
    final currentGroup = ref.read(currentGroupProvider);
    final currentBranch = ref.read(currentBranchProvider);
    final currentOrg = ref.read(currentOrganizationProvider);
    
    if (currentGroup == null || currentBranch == null || currentOrg == null) {
      _showMessage("Please select organization, branch and group first", false);
      return;
    }
    
    final csvService = ref.read(csvServiceProvider);
    
    try {
      // Show file picker
      final file = await csvService.pickCsvFile();
      if (file == null) return;
      
      // Show loading indicator for headers extraction
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading CSV file...'),
            ],
          ),
        ),
      );
      
      // Extract headers from CSV
      final headers = await csvService.extractCsvHeaders(file);
      
      // Hide loading indicator
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Show mapping screen
      final fieldMapping = await csvService.showMappingScreen(context, headers);
      
      // If user canceled mapping, exit
      if (fieldMapping == null) return;
      
      // Show loading indicator for import
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Importing employees...'),
            ],
          ),
        ),
      );
      
      // Parse CSV with the mapping
      final employeesData = await csvService.parseEmployeesCsv(file, fieldMapping);
      
      // Import employees
      await ref.read(employeeProvider.notifier).importEmployeesFromCsvData(
        currentOrg.id,
        currentBranch.id,
        currentGroup.id,
        employeesData,
      );
      
      // Hide loading indicator
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Show success message
      _showMessage('${employeesData.length} employees imported successfully', true);
      
      // Force UI refresh
      setState(() {});
      
      // Extra check: Explicitly refresh the employee list
      ref.refresh(employeeProvider);
      
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Show error message
      _showMessage('Error: ${e.toString()}', false);
    }
  }
}