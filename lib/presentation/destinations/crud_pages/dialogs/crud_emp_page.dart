import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateEditEmployeePage extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPhone;
  final String? initialEmail;
  final Map<String, String>? initialDynamicFields;
  final void Function(String name, String phone, String email, Map<String, String> fields) onSubmit;

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
  late Map<String, TextEditingController> _dynamicFieldControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _emailController = TextEditingController(text: widget.initialEmail);

    // Initialize controllers for dynamic fields
    _dynamicFieldControllers = {
      for (var entry in (widget.initialDynamicFields ?? {}).entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();

    // Dispose dynamic field controllers
    for (var controller in _dynamicFieldControllers.values) {
      controller.dispose();
    }

    super.dispose();
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
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dynamicFieldControllers.length,
                itemBuilder: (context, index) {
                  String key = _dynamicFieldControllers.keys.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: TextEditingController(text: key),
                            decoration: InputDecoration(
                              labelText: "Title",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            onChanged: (newKey) {
                              setState(() {
                                String? value = _dynamicFieldControllers[key]?.text;
                                _dynamicFieldControllers.remove(key);
                                _dynamicFieldControllers[newKey] =
                                    TextEditingController(text: value);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _dynamicFieldControllers[key],
                            decoration: InputDecoration(
                              labelText: "Detail",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            onChanged: (value) {
                              _dynamicFieldControllers[key]?.text = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _dynamicFieldControllers.remove(key);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text(
                  "Add Custom Field",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  setState(() {
                    String newKey = "New Field ${_dynamicFieldControllers.length + 1}";
                    _dynamicFieldControllers[newKey] = TextEditingController();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () {
            final name = _nameController.text;
            final phone = _phoneController.text;
            final email = _emailController.text;

            // Convert dynamic controllers to map
            final dynamicFields = {
              for (var entry in _dynamicFieldControllers.entries) entry.key: entry.value.text,
            };

            widget.onSubmit(name, phone, email, dynamicFields);
            context.pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: const Text(
            "SAVE",
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
