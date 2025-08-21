import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../services/base/database/hive_manager/models.dart';

class CreateEditEmployeeScreen extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhone;
  final String? initialEmail;
  final Map<String, Map<String, String>>? initialDynamicFields;
  final Function(String name, String phone, String email, Map<String, Map<String, String>> dynamicFields) onSave;

  const CreateEditEmployeeScreen({
    super.key,
    required this.title,
    this.initialName,
    this.initialPhone,
    this.initialEmail,
    this.initialDynamicFields,
    required this.onSave,
  });

  @override
  _CreateEditEmployeeScreenState createState() => _CreateEditEmployeeScreenState();
}

class _CreateEditEmployeeScreenState extends State<CreateEditEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  
  // Map to store dynamic field controllers
  final Map<String, Map<String, TextEditingController>> _dynamicFieldControllers = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _phoneController = TextEditingController(text: widget.initialPhone ?? '');
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    
    // Initialize dynamic field controllers
    if (widget.initialDynamicFields != null) {
      widget.initialDynamicFields!.forEach((category, fields) {
        _dynamicFieldControllers[category] = {};
        fields.forEach((field, value) {
          _dynamicFieldControllers[category]![field] = TextEditingController(text: value);
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    
    // Dispose dynamic field controllers
    _dynamicFieldControllers.forEach((category, controllers) {
      controllers.forEach((field, controller) {
        controller.dispose();
      });
    });
    
    super.dispose();
  }

  // Helper to get all dynamic fields as a structured map
  Map<String, Map<String, String>> _getDynamicFieldsValues() {
    Map<String, Map<String, String>> result = {};
    
    _dynamicFieldControllers.forEach((category, controllers) {
      result[category] = {};
      controllers.forEach((field, controller) {
        result[category]?[field] = controller.text;
      });
    });
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                widget.onSave(
                  _nameController.text,
                  _phoneController.text,
                  _emailController.text,
                  _getDynamicFieldsValues(),
                );
                Navigator.pop(context);
              }
            },
            child: Text(
              'save'.tr(),
              style: TextStyle(color: Colors.grey[700], fontSize: 20),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Basic fields
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'name'.tr(),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'phone'.tr(),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'email'.tr(),
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Dynamic fields
            if (_dynamicFieldControllers.isNotEmpty) ...[
              ..._dynamicFieldControllers.entries.map((categoryEntry) {
                String category = categoryEntry.key;
                Map<String, TextEditingController> fieldControllers = categoryEntry.value;
                
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category == 'csvImported' ? 'Additional Information' : category,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 16),
                        ...fieldControllers.entries.map((fieldEntry) {
                          String fieldName = fieldEntry.key;
                          TextEditingController controller = fieldEntry.value;
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: TextFormField(
                              controller: controller,
                              decoration: InputDecoration(
                                labelText: fieldName,
                                border: OutlineInputBorder(),
                                prefixIcon: _getIconForField(fieldName),
                              ),
                              keyboardType: _getKeyboardTypeForField(fieldName),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
            ],
            
            SizedBox(height: 16),
            
            // Add a new dynamic field button
            ElevatedButton.icon(
              onPressed: _showAddFieldDialog,
              icon: Icon(Icons.add),
              label: Text('Add Custom Field'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to determine keyboard type based on field name
  TextInputType _getKeyboardTypeForField(String fieldName) {
    fieldName = fieldName.toLowerCase();
    
    if (fieldName.contains('phone') || fieldName.contains('mobile') || 
        fieldName.contains('no') || fieldName.contains('number')) {
      return TextInputType.phone;
    } else if (fieldName.contains('email') || fieldName.contains('mail')) {
      return TextInputType.emailAddress;
    } else if (fieldName.contains('date')) {
      return TextInputType.datetime;
    } else if (fieldName.contains('salary') || fieldName.contains('amount') || 
              fieldName.contains('price') || fieldName.contains('cost')) {
      return TextInputType.number;
    }
    
    return TextInputType.text;
  }
  
  // Helper to get an appropriate icon for each field type
  Icon? _getIconForField(String fieldName) {
    fieldName = fieldName.toLowerCase();
    
    if (fieldName.contains('bank') || fieldName.contains('account') || fieldName.contains('bacno')) {
      return Icon(Icons.account_balance);
    } else if (fieldName.contains('date') || fieldName.contains('doj')) {
      return Icon(Icons.calendar_today);
    } else if (fieldName.contains('education') || fieldName.contains('qual')) {
      return Icon(Icons.school);
    } else if (fieldName.contains('design') || fieldName.contains('position') || fieldName.contains('job')) {
      return Icon(Icons.work);
    } else if (fieldName.contains('epf') || fieldName.contains('uan')) {
      return Icon(Icons.numbers);
    } else if (fieldName.contains('esic')) {
      return Icon(Icons.health_and_safety);
    }
    
    return Icon(Icons.description);
  }

  // Show dialog to add a new custom field
  void _showAddFieldDialog() {
    final TextEditingController fieldNameController = TextEditingController();
    final TextEditingController fieldValueController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Custom Field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: fieldNameController,
                decoration: InputDecoration(
                  labelText: 'Field Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: fieldValueController,
                decoration: InputDecoration(
                  labelText: 'Field Value',
                  border: OutlineInputBorder(),
                ),
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
                if (fieldNameController.text.isNotEmpty) {
                  setState(() {
                    // Use 'custom' as the category for user-added fields
                    if (!_dynamicFieldControllers.containsKey('custom')) {
                      _dynamicFieldControllers['custom'] = {};
                    }
                    
                    _dynamicFieldControllers['custom']![fieldNameController.text] = 
                        TextEditingController(text: fieldValueController.text);
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}