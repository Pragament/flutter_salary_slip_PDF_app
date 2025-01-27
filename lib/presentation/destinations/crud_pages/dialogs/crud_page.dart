import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateEditPage extends StatefulWidget {
  final String title;
  final String? initialName;
  final Map<String, String>? initialDynamicFields;
  final void Function(String name, Map<String, String> dynamicFields) onSubmit;

  const CreateEditPage({
    Key? key,
    required this.title,
    this.initialName,
    this.initialDynamicFields,
    required this.onSubmit,
  }) : super(key: key);

  @override
  _CreateEditPageState createState() => _CreateEditPageState();
}

class _CreateEditPageState extends State<CreateEditPage> {
  late TextEditingController _nameController;
  late Map<String, TextEditingController> _dynamicFieldControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);

    // Initialize controllers for dynamic fields
    _dynamicFieldControllers = {
      for (var entry in (widget.initialDynamicFields ?? {}).entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();

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
                  labelText: "Name",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
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
                        Center(
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _dynamicFieldControllers.remove(key);
                              });
                            },
                          ),
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
            // Extract dynamic fields into a map
            final dynamicFields = {
              for (var entry in _dynamicFieldControllers.entries) entry.key: entry.value.text,
            };

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
          child: const Text(
            "SAVE",
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
