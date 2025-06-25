import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_template/presentation/destinations/crud_pages/csv_mapping_screen.dart';

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


  Future<List<String>> extractCsvHeaders(File file) async {
    try {
      final csvString = await file.readAsString();
      print("Raw CSV content (first 500 chars): ${csvString.substring(0, csvString.length > 500 ? 500 : csvString.length)}");
      
    
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        allowInvalid: false,
      ).convert(csvString);
      
      if (csvTable.isEmpty) {
        print("CSV table is empty after parsing");
        return [];
      }
      
     
      List<String> headers = csvTable[0].map((e) => e.toString().trim()).toList();
      
     
      headers = headers.map((h) => h.replaceAll('"', '').trim()).toList();
      headers = headers.where((header) => header.isNotEmpty).toList();
      
      print("Extracted headers: $headers");
      return headers;
      
    } catch (e) {
      print("Error extracting headers: $e");
      
      
      try {
        print("Attempting manual header parsing...");
        final csvString = await file.readAsString();
        
        
        List<String> lines = csvString.split('\n');
        if (lines.isEmpty) return [];
        
        
        String headerLine = lines[0].trim();
        print("Header line: $headerLine");
        
        
        List<String> headers = [];
        bool inQuotes = false;
        String currentField = '';
        
        for (int i = 0; i < headerLine.length; i++) {
          String char = headerLine[i];
          
          if (char == '"') {
            inQuotes = !inQuotes;
          } else if (char == ',' && !inQuotes) {
            headers.add(currentField.trim());
            currentField = '';
          } else {
            currentField += char;
          }
        }
        
        // Add the last field
        if (currentField.isNotEmpty) {
          headers.add(currentField.trim());
        }
        
        
        headers = headers.map((h) => h.replaceAll('"', '').trim()).toList();
        headers = headers.where((header) => header.isNotEmpty).toList();
        
        print("Manual parsing extracted headers: $headers");
        return headers;
        
      } catch (manualError) {
        print("Manual parsing also failed: $manualError");
        return [];
      }
    }
  }

  
  Future<List<Map<String, dynamic>>> parseEmployeesCsv(
    File file, 
    Map<String, String> fieldMapping
  ) async {
    try {
      final csvString = await file.readAsString();
      print("Parsing CSV with field mapping: $fieldMapping");
      
      
      List<List<dynamic>> csvTable = const CsvToListConverter(
        fieldDelimiter: ',',
        textDelimiter: '"',
        eol: '\n',
        allowInvalid: false,
      ).convert(csvString);
      
      if (csvTable.isEmpty || csvTable.length < 2) {
        print("CSV is empty or has no data rows");
        return [];
      }
      
      List<String> headers = csvTable[0].map((e) => e.toString().trim()).toList();
      print("CSV headers from parsing: $headers");
      
      List<Map<String, dynamic>> employees = [];
      
     
      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        print("Processing row $i: $row");
        
      
        if (row.isEmpty || row.every((cell) => cell == null || cell.toString().trim().isEmpty)) {
          print("Skipping empty row $i");
          continue;
        }
        
        Map<String, dynamic> employee = {
          'name': '',
          'phone': '',
          'email': '',
        };
        
        
        Map<String, String> dynamicFields = {};
        
       
        for (int j = 0; j < headers.length && j < row.length; j++) {
          String headerName = headers[j];
          String fieldName = fieldMapping[headerName] ?? '';
          String value = (row[j] ?? '').toString().trim();
          
          print("Mapping '$headerName' (value: '$value') to '$fieldName'");
          
         
          if (fieldName == 'Skip' || fieldName.isEmpty) {
            print("Skipping field '$headerName'");
            continue;
          }
          
  
          if (fieldName == 'name') {
            employee['name'] = value;
          } else if (fieldName == 'email') {
            employee['email'] = value;
          } else if (fieldName == 'phone') {
            employee['phone'] = value;
          } else {
            // Add to dynamic fields if it's not a core field but has a mapping
            dynamicFields[fieldName] = value;
          }
        }
        
       
        if (employee['name'].toString().isNotEmpty || employee['email'].toString().isNotEmpty) {
          employee['dynamicFields'] = dynamicFields;
          employees.add(employee);
          print("Added employee: ${employee['name']} (${employee['email']}) with ${dynamicFields.length} dynamic fields");
        } else {
          print("Skipping employee with no name or email");
        }
      }
      
      print("Total employees parsed: ${employees.length}");
      return employees;
      
    } catch (e) {
      print("Error parsing CSV: $e");
      rethrow;
    }
  }
}