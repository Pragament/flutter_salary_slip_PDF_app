import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../csv_mapping/csv_mapping_screen.dart';

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

  /// Shows the mapping screen and returns the field mapping
  Future<Map<String, String>?> showMappingScreen(BuildContext context, List<String> csvHeaders) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => CsvMappingScreen(
          csvHeaders: csvHeaders,
          onMappingComplete: (mapping) {
            Navigator.pop(context, mapping);
          },
        ),
      ),
    );
    return result;
  }

  /// Parses CSV file to extract headers only
  Future<List<String>> extractCsvHeaders(File file) async {
    final csvString = await file.readAsString();
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
    
    if (csvTable.isEmpty) return [];
    
    return csvTable[0].map((e) => e.toString().trim()).toList();
  }

  /// Parses CSV file to a list of employee data using provided field mapping
  Future<List<Map<String, dynamic>>> parseEmployeesCsv(
    File file, 
    Map<String, String> fieldMapping
  ) async {
    final csvString = await file.readAsString();
    List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
    
    if (csvTable.isEmpty) return [];
    
    List<String> headers = csvTable[0].map((e) => e.toString().trim()).toList();
    List<Map<String, dynamic>> employees = [];
    
    // Process each row into an employee data map
    for (int i = 1; i < csvTable.length; i++) {
      final row = csvTable[i];
      if (row.length < headers.length) continue; // Skip invalid rows
      
      Map<String, dynamic> employee = {
        'name': '',
        'phone': '',
        'email': '',
      };
      
      // Dynamic fields to store additional data
      Map<String, String> dynamicFields = {};
      
      // Map each CSV column to the appropriate field
      for (int j = 0; j < headers.length && j < row.length; j++) {
        String headerName = headers[j];
        String fieldName = fieldMapping[headerName] ?? '';
        String value = row[j].toString().trim();
        
        // Skip this field if it's mapped to 'Skip'
        if (fieldName == 'Skip') continue;
        
        // Map to core employee fields
        if (fieldName == 'name') {
          employee['name'] = value;
        } else if (fieldName == 'email') {
          employee['email'] = value;
        } else if (fieldName == 'phone') {
          employee['phone'] = value;
        } else if (fieldName != '') {
          // Add to dynamic fields if it's not a core field but has a mapping
          dynamicFields[fieldName] = value;
        }
      }
      
      employee['dynamicFields'] = dynamicFields;
      employees.add(employee);
    }
    
    return employees;
  }
}