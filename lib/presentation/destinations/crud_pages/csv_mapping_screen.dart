import 'package:flutter/material.dart';
class CsvMappingScreen extends StatefulWidget {
  final List<String> csvHeaders;
  final Function(Map<String, String>) onMappingComplete;

  const CsvMappingScreen({
    super.key,
    required this.csvHeaders,
    required this.onMappingComplete,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CsvMappingScreenState createState() => _CsvMappingScreenState();
}

class _CsvMappingScreenState extends State<CsvMappingScreen> {
  final Map<String, String> fieldMapping = {};
  List<String> appFields = [
    'name',
    'email',
    'phone',
    'bankAccountNo',
    'dateOfJoining',
    'qualification',
    'designation',
    'epfUanNo',
    'esicNo',
    // Add other fields as needed
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with default mappings
    for (var header in widget.csvHeaders) {
      String? defaultMapping = _findDefaultMapping(header);
      fieldMapping[header] = defaultMapping ?? 'Create New Field';
    }
  }

  String? _findDefaultMapping(String header) {
    // Try to match CSV header with app fields
    String normalized = header.toLowerCase().trim();
    
    // Common mappings
    Map<String, String> commonMappings = {
      'empname': 'name',
      'employee name': 'name',
      'name': 'name',
      'email': 'email',
      'email id': 'email',
      'mail id': 'email',
      'phone': 'phone',
      'phone number': 'phone',
      'mobile': 'phone',
      'bacno': 'bankAccountNo',
      'bank a/c no': 'bankAccountNo',
      'bank account': 'bankAccountNo',
      'bank account no': 'bankAccountNo',
      'doj': 'dateOfJoining',
      'date of joining': 'dateOfJoining',
      'qual': 'qualification',
      'qualification': 'qualification',
      'desig': 'designation',
      'design': 'designation',
      'designation': 'designation',
      'epf uan no': 'epfUanNo',
      'epf uan number': 'epfUanNo',
      'epf': 'epfUanNo',
      'esic_no': 'esicNo',
      'esic no': 'esicNo',
      'esic': 'esicNo',
    };
    
    // Look for exact match in common mappings
    for (var entry in commonMappings.entries) {
      if (normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    
    // If no exact match, try fuzzy matching with app fields
    for (var field in appFields) {
      if (normalized.contains(field.toLowerCase())) {
        return field;
      }
    }
    
    return null;
  }

  bool _validateMapping() {
    // Check that we have the essential fields mapped (name and email at minimum)
    bool hasName = false;
    bool hasEmail = false;
    
    for (var value in fieldMapping.values) {
      if (value == 'name') hasName = true;
      if (value == 'email') hasEmail = true;
      
      if (hasName && hasEmail) return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map CSV Fields'),
        actions: [
          TextButton(
            onPressed: () {
              if (_validateMapping()) {
                widget.onMappingComplete(fieldMapping);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please map at least name and email fields'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(
              'Apply',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Text(
            'Match CSV columns to app fields',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Map each CSV column to the appropriate field in the app. Required fields are name and email.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          Divider(height: 32),
          ...widget.csvHeaders.map((header) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CSV Field: "$header"',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Map to: '),
                          SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: fieldMapping[header],
                              items: [
                                ...appFields.map((field) => DropdownMenuItem(
                                      value: field,
                                      child: Text(field),
                                    )),
                                DropdownMenuItem(
                                  value: 'Create New Field',
                                  child: Text('Create New Field'),
                                ),
                                DropdownMenuItem(
                                  value: 'Skip',
                                  child: Text('Skip This Field'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == 'Create New Field') {
                                  _showCreateFieldDialog(header);
                                } else if (value != null) {
                                  setState(() {
                                    fieldMapping[header] = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (fieldMapping[header] == 'name' || fieldMapping[header] == 'email')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Required field',
                            style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_validateMapping()) {
            print("Mapping complete with: $fieldMapping"); // Debug print
            widget.onMappingComplete(fieldMapping);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please map at least name and email fields'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        tooltip: 'Complete Mapping',
        child: Icon(Icons.check),
      ),
    );
  }

  void _showCreateFieldDialog(String header) {
    final TextEditingController controller = TextEditingController();
    controller.text = _normalizeCsvHeader(header);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter a name for the new field to store the CSV data in.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Field Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final newField = controller.text.trim();
                  setState(() {
                    // Add to app fields
                    if (!appFields.contains(newField)) {
                      appFields.add(newField);
                    }
                    // Update mapping
                    fieldMapping[header] = newField;
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }
  
  // Helper to convert CSV header to a clean field name
  String _normalizeCsvHeader(String header) {
    // Convert to camelCase
    String result = header.toLowerCase().trim();
    
    // Replace non-alphanumeric with spaces
    result = result.replaceAll(RegExp(r'[^a-z0-9]'), ' ');
    
    // Title case words
    List<String> words = result.split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    
    if (words.isEmpty) return '';
    
    // First word lowercase, rest title case
    result = words[0].toLowerCase();
    
    // Append rest of words with first letter capitalized
    for (int i = 1; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        result += words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    
    return result;
  }
}