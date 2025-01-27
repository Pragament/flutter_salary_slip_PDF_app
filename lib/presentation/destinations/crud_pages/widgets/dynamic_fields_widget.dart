// import 'package:flutter/material.dart';
//
// class DynamicFieldsEditor extends StatefulWidget {
//   final Map<String, String> initialFields;
//   final void Function(Map<String, String>) onFieldsChanged;
//
//   const DynamicFieldsEditor({
//     Key? key,
//     required this.initialFields,
//     required this.onFieldsChanged,
//   }) : super(key: key);
//
//   @override
//   _DynamicFieldsEditorState createState() => _DynamicFieldsEditorState();
// }
//
// class _DynamicFieldsEditorState extends State<DynamicFieldsEditor> {
//   late Map<String, String> fields;
//
//   @override
//   void initState() {
//     super.initState();
//     fields = Map<String, String>.from(widget.initialFields);
//   }
//
//   void _addField() {
//     setState(() {
//       fields['New Field ${fields.length + 1}'] = ''; // Provide a default unique key
//     });
//     widget.onFieldsChanged(fields);
//   }
//
//   void _updateField(String oldKey, String newKey, String value) {
//     setState(() {
//       if (oldKey != newKey) {
//         fields.remove(oldKey);
//       }
//       fields[newKey] = value;
//     });
//     widget.onFieldsChanged(fields);
//   }
//
//   void _deleteField(String key) {
//     setState(() {
//       fields.remove(key);
//     });
//     widget.onFieldsChanged(fields);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         ListView.builder(
//           shrinkWrap: true,
//           itemCount: fields.length,
//           itemBuilder: (context, index) {
//             final key = fields.keys.elementAt(index);
//             return Row(
//               children: [
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: key,
//                     decoration: InputDecoration(labelText: "Field Title"),
//                     onChanged: (newKey) {
//                       final value = fields[key] ?? ''; // Handle null values safely
//                       _updateField(key, newKey, value);
//                     },
//                   ),
//                 ),
//                 Expanded(
//                   child: TextFormField(
//                     initialValue: fields[key] ?? '', // Handle null values safely
//                     decoration: InputDecoration(labelText: "Field Content"),
//                     onChanged: (value) => _updateField(key, key, value),
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.delete),
//                   onPressed: () => _deleteField(key),
//                 ),
//               ],
//             );
//           },
//         ),
//         TextButton.icon(
//           icon: Icon(Icons.add),
//           label: Text("Add Field"),
//           onPressed: _addField,
//         ),
//       ],
//     );
//   }
// }
