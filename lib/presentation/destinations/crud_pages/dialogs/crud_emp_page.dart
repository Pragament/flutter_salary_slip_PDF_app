import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/dynamic_fields_widget.dart';

class CreateEditEmployeePage extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhone;
  final String? initialEmail;
  final Map<String,Map<String, String>>? initialDynamicFields;
  final void Function(String name, String phone, String email, Map<String,Map<String, String>> fields) onSubmit;

  const CreateEditEmployeePage({
    required this.title,
    this.initialName,
    this.initialPhone,
    this.initialEmail,
    this.initialDynamicFields,
    required this.onSubmit,
    super.key,
  });

  @override
  _CreateEditEmployeePageState createState() => _CreateEditEmployeePageState();
}

class _CreateEditEmployeePageState extends State<CreateEditEmployeePage> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late Map<String,Map<String, String>> dynamicFields;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);
    dynamicFields = Map<String,Map<String, String>>.from(widget.initialDynamicFields ?? {});
  }

  void _onFieldsChanged(Map<String,Map<String, String>> updatedFields) {
    setState(() {
      dynamicFields = updatedFields;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField("name".tr(), _nameController),
              _buildTextField("phone".tr(), _phoneController),
              _buildTextField("email".tr(), _emailController),
              const SizedBox(height: 16),

              // Dynamic Fields Section (Integrated with DynamicFieldsEditor)
              DynamicFieldsEditor(
                initialFields: dynamicFields,
                onFieldsChanged: _onFieldsChanged,
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  widget.onSubmit(
                    _nameController.text,
                    _phoneController.text,
                    _emailController.text,
                    dynamicFields,
                  );
                  context.pop();
                },
                child:  Text("save".tr(), style: TextStyle(fontSize: 18, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
