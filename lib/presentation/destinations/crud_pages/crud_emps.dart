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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("noGrpSelected".tr())),
      );
      return;
    }
    
    final csvService = ref.read(csvServiceProvider);
    
    try {
      // Show file picker
      final file = await csvService.pickCsvFile();
      if (file == null) return;
      
      // Show loading indicator
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
      
      // Parse CSV
      final employeesData = await csvService.parseEmployeesCsv(file);
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${employeesData.length} employees imported successfully')),
      );
    } catch (e) {
      // Hide loading indicator if still showing
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }
}
// import 'dart:io';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import '../../../services/base/database/hive_manager/models.dart';
// import '../../../services/base/id_generator.dart';
// import '../../../services/providers/cur_branch_provider.dart';
// import '../../../services/providers/cur_group_provider.dart';
// import '../../../services/providers/cur_org_provider.dart';
// import '../../../services/providers/emp_provider.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:csv/csv.dart';

// class ManageEmployeesScreen extends ConsumerStatefulWidget {
//   const ManageEmployeesScreen({super.key});

//   @override
//   ConsumerState<ManageEmployeesScreen> createState() => _ManageBranchesScreenState();
// }

// class _ManageBranchesScreenState extends ConsumerState<ManageEmployeesScreen> {

//   @override
//   Widget build(BuildContext context) {
//     final currentGroup = ref.watch(currentGroupProvider);
//     final currentBranch = ref.watch(currentBranchProvider);
//     final currentOrg = ref.watch(currentOrganizationProvider);
//     if (currentGroup == null) {
//       return Scaffold(
//         appBar: AppBar(title: Text("manageEmp".tr())),
//         body: Center(child: Text("noGrpSelected".tr())),
//       );
//     }

//     final employees = ref.watch(employeeProvider);
//     print(employees?.isEmpty);


//     return Scaffold(
//       appBar: AppBar(
//         title: Text("${"manageEmp".tr()} - ${currentGroup.name}"),
//       ),
//       body: (employees==null || employees.isEmpty)?Center(child: Text("noEmp".tr())):ListView.builder(
//         itemCount: employees.length,
//         itemBuilder: (context, index) {
//           final employee = employees[index];
//           return Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Card(
//               elevation: 3,
//               color: Colors.grey.shade100,
//               child: ListTile(
//                 title: Text(employee.name,style: TextStyle(color: Colors.black)),
//                 subtitle: Text(employee.email,style: TextStyle(color: Colors.black)),
//                 trailing: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     IconButton(
//                       icon: Icon(Icons.edit),
//                       onPressed: () =>context.push("/create-edit-emp",
//                           extra: {
//                         "title":"editEmp".tr(),
//                                 'initialName': employee.name,
//                                 'initialPhone': employee.phone,
//                                 'initialEmail': employee.email,
//                                 'initialDynamicFields': employee.dynamicFields,
//                         'onSave':(name, phone, email, fields) {
//                                 final updatedEmployee = Employee(
//                                     name, phone, email, fields, employee.id);
//                                 ref.read(employeeProvider.notifier).updateEmployee(
//                                     currentOrg!.id,
//                                     currentBranch!.id,
//                                     currentGroup.id,
//                                     updatedEmployee);
//                               },
//                             })
//                     ),
//                     IconButton(
//                       icon: Icon(Icons.delete),
//                       onPressed: () =>
//                           ref
//                               .read(employeeProvider.notifier)
//                               .deleteEmployee(
//                               currentOrg!.id, currentBranch!.id, currentGroup.id,
//                               employee.id),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//       floatingActionButton: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           // CSV Import button - positioned at bottom right
//           FloatingActionButton(
//             heroTag: 'csvImport',
//             onPressed: () => _importCSV(context),
//             tooltip: 'Import CSV',
//             child: const Icon(Icons.file_upload),
//           ),
//           const SizedBox(height: 16),
//           // Original Add button
//           FloatingActionButton(
//             heroTag: 'addEmployee',
//             onPressed: () =>context.push("/create-edit-emp",extra: {
//               "title":"createEmp".tr(),
//               'initialName': null,
//               'initialPhone': null,
//               'initialEmail': null,
//               'initialDynamicFields': null,
//                 "onSave": (name, phone, email, fields) {
//                   final newEmployee = Employee(
//                       name, phone, email, fields, generateId());
//                   ref.read(employeeProvider.notifier).addEmployee(
//                       currentOrg!.id, currentBranch!.id, currentGroup.id,
//                       newEmployee);
//                 },
//             }),
//             child: Icon(Icons.add),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _importCSV(BuildContext context) async {
//     final currentGroup = ref.read(currentGroupProvider);
//     final currentBranch = ref.read(currentBranchProvider);
//     final currentOrg = ref.read(currentOrganizationProvider);
    
//     if (currentGroup == null || currentBranch == null || currentOrg == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Please select organization, branch and group first")),
//       );
//       return;
//     }

//     try {
//       // Pick file
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['csv'],
//       );

//       if (result == null || result.files.single.path == null) return;

//       // Read file
//       final file = File(result.files.single.path!);
//       final contents = await file.readAsString();
      
//       // Parse CSV
//       List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(contents);
      
//       // Skip header row if present
//       if (rowsAsListOfValues.isNotEmpty) {
//         rowsAsListOfValues = rowsAsListOfValues.sublist(1);
//       }
      
//       int importedCount = 0;
      
//       // Process each row
//       for (var row in rowsAsListOfValues) {
//         if (row.length < 8) continue; // Skip incomplete rows
        
//         // The CSV format as specified:
//         // 0: doj (date of joining)
//         // 1: empname (employee name)
//         // 2: qual (qualification)
//         // 3: desig (designation)
//         // 4: EPF UAN NO
//         // 5: esic_no
//         // 6: bacno (bank account number)
//         // 7: EMAIL ID
        
//         // Create a nested map structure for dynamicFields
//         Map<String, Map<String, String>> dynamicFields = {};
        
//         // Add an inner map for employee details
//         dynamicFields['employee_details'] = {
//           'dateOfJoining': row[0].toString(),
//           'qualification': row[2].toString(),
//           'designation': row[3].toString(),
//           'epfUanNo': row[4].toString(),
//           'esicNo': row[5].toString(),
//           'bankAccountNo': row[6].toString(),
//         };
        
//         // Create employee with the CSV data
//         final newEmployee = Employee(
//           row[1].toString(), // name (empname)
//           "", // phone (not in CSV, setting empty)
//           row[7].toString(), // email (EMAIL ID)
//           dynamicFields,
//           generateId() // generate new ID
//         );
        
//         // Add to your provider
//         ref.read(employeeProvider.notifier).addEmployee(
//           currentOrg.id,
//           currentBranch.id,
//           currentGroup.id,
//           newEmployee
//         );
        
//         importedCount++;
//       }
      
//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Successfully imported $importedCount employees')),
//       );
//     } catch (e) {
//       // Show error message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error importing CSV: ${e.toString()}')),
//       );
//     }
//   }
// }