import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class EmployeeCsvService {
  /// Picks a CSV file from the device
  Future<File?> pickCsvFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  /// Parses CSV file to a list of employee data
  Future<List<Map<String, dynamic>>> parseEmployeesCsv(File file) async {
    final csvString = await file.readAsString();
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
    
    if (csvTable.isEmpty) return [];
    
    // Find indices for required fields
    Map<String, int> fieldIndices = {};
    List<String> headers = csvTable[0].map((e) => e.toString().trim()).toList();
    
    // The CSV format from the GitHub issue
    final requiredFields = [
      {'key': 'bankAccountNo', 'aliases': ['bacno', 'bank a/c no', 'bank account']},
      {'key': 'email', 'aliases': ['email id', 'mail id', 'email']},
      {'key': 'name', 'aliases': ['empname', 'employee name', 'name']},
      {'key': 'dateOfJoining', 'aliases': ['doj', 'dateofjoining', 'date of joining']},
      {'key': 'qualification', 'aliases': ['qual', 'qualification']},
      {'key': 'designation', 'aliases': ['desig', 'designation']},
      {'key': 'epfUanNo', 'aliases': ['epf uan no', 'epf']},
      {'key': 'esicNo', 'aliases': ['esic_no', 'esic no', 'esic']},
    ];
    
    // Find column indices for each required field
    for (var field in requiredFields) {
      final key = field['key'] as String;
      final aliases = field['aliases'] as List<String>;
      
      // Try to find a column header that matches any of the aliases
      bool found = false;
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i].toLowerCase();
        for (var alias in aliases) {
          if (header.contains(alias.toLowerCase())) {
            fieldIndices[key] = i;
            found = true;
            break;
          }
        }
        if (found) break;
      }
      
      // If we couldn't find this required field, throw an exception
      if (!found) {
        throw Exception('CSV is missing required column: ${aliases.join(" or ")}');
      }
    }
    
    // Process each row into an employee data map
    List<Map<String, dynamic>> employees = [];
    
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length < headers.length) continue; // Skip invalid rows
      
      Map<String, dynamic> employee = {};
      
      // Extract each field using the indices we found
      for (var entry in fieldIndices.entries) {
        final key = entry.key;
        final index = entry.value;
        employee[key] = row[index].toString().trim();
      }
      
      // Add any additional fields as dynamic fields
      Map<String, String> dynamicFields = {};
      for (int j = 0; j < headers.length; j++) {
        if (!fieldIndices.values.contains(j)) {
          dynamicFields[headers[j]] = row[j].toString().trim();
        }
      }
      
      employee['dynamicFields'] = dynamicFields;
      employees.add(employee);
    }
    
    return employees;
  }
}