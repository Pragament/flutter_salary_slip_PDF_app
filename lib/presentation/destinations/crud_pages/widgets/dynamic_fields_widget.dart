import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class DynamicFieldsEditor extends StatefulWidget {
  final Map<String, Map<String, String>> initialFields; // Now initial fields are Map<String, Map<String, String>>
  final void Function(Map<String, Map<String, String>>) onFieldsChanged;

  const DynamicFieldsEditor({
    Key? key,
    required this.initialFields,
    required this.onFieldsChanged,
  }) : super(key: key);

  @override
  _DynamicFieldsEditorState createState() => _DynamicFieldsEditorState();
}

class _DynamicFieldsEditorState extends State<DynamicFieldsEditor> {
  late Map<String, Map<String, String>> fields; // To store id, title, and content
  int fieldCounter = 0; // Counter for generating unique IDs

  @override
  void initState() {
    super.initState();
    fields = Map<String, Map<String, String>>.from(widget.initialFields); // Initialize fields with the passed data
  }

  void _addField() {
    setState(() {
      String newId = 'Field_${fieldCounter++}';
      fields[newId] = {'title': 'New Field ${fieldCounter}', 'content': ''};  // Default title and empty content
    });
    widget.onFieldsChanged(fields);  // Notify parent widget of the update
  }

  void _updateField(String id, String title, String content) {
    setState(() {
      fields[id] = {'title': title, 'content': content};  // Update the title and content for the field
    });
    widget.onFieldsChanged(fields);  // Notify parent widget of the update
  }

  void _deleteField(String id) {
    setState(() {
      fields.remove(id);  // Remove the field by id
    });
    widget.onFieldsChanged(fields);  // Notify parent widget of the update
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: fields.length,
            itemBuilder: (context, index) {
              String id = fields.keys.elementAt(index);
      
              // Access title and content for the current field
              String title = fields[id]?['title'] ?? '';
              String content = fields[id]?['content'] ?? '';
      
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    // Title field
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: title,  // Initialize with the title of the field
                        decoration: InputDecoration(
                          labelText: "fieldTitle".tr(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onChanged: (newTitle) {
                          final content = fields[id]?['content'] ?? ''; // Get current content
                          _updateField(id, newTitle, content);  // Update the field with the new title and existing content
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content field
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: content,  // Initialize with the content of the field
                        decoration: InputDecoration(
                          labelText: "fieldContent".tr(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        onChanged: (newContent) {
                          final title = fields[id]?['title'] ?? ''; // Get current title
                          _updateField(id, title, newContent);  // Update the field with the new content and existing title
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button for dynamic fields
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteField(id),  // Delete the field by id
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Add Custom Field Button
          TextButton.icon(
            icon: const Icon(Icons.add,color: Colors.white,),
            label:  Text("addField".tr(), style: TextStyle(color: Colors.white)),
            onPressed: _addField,  // Call _addField to add a new field
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }
}
