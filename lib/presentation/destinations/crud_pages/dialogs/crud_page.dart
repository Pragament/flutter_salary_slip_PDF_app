import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/dynamic_fields_widget.dart';

class CreateEditPage extends StatefulWidget {
  final String title;
  final String? initialName;
  final Map<String,Map<String, String>>? initialDynamicFields;
  final void Function(String name, Map<String,Map<String, String>> dynamicFields) onSubmit;

  const CreateEditPage({
    super.key,
    required this.title,
    this.initialName,
    this.initialDynamicFields,
    required this.onSubmit,
  });

  @override
  _CreateEditPageState createState() => _CreateEditPageState();
}

class _CreateEditPageState extends State<CreateEditPage> {
  late TextEditingController _nameController;
  late Map<String,Map<String, String>> dynamicFields;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "name".tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),

              // Use DynamicFieldsEditor for dynamic fields
              DynamicFieldsEditor(
                initialFields: dynamicFields,
                onFieldsChanged: _onFieldsChanged,
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  widget.onSubmit(_nameController.text, dynamicFields);
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child:  Text(
                  "save".tr(),
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
