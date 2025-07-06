import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/dynamic_fields_widget.dart';

class ManageBusinessPage extends StatefulWidget {
  final String title;
  final String? initialCompanyName;
  final String? initialAddress;
  final String? initialEmail;
  final String? initialPhone;
  final Uint8List? initialImg;
  final Map<String,Map<String, String>>? initialDynamicFields;
  final void Function(String companyName, String address, String email, String phone,
      Map<String,Map<String, String>> dynamicFields, Uint8List? image) onSubmit;

  const ManageBusinessPage({
    super.key,
    required this.title,
    this.initialCompanyName,
    this.initialAddress,
    this.initialEmail,
    this.initialPhone,
    this.initialDynamicFields,
    this.initialImg,
    required this.onSubmit,
  });

  @override
  _ManageBusinessPageState createState() => _ManageBusinessPageState();
}

class _ManageBusinessPageState extends State<ManageBusinessPage> {
  late TextEditingController _companyNameController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  Uint8List? img;

  // Use a map to store dynamic fields (title, content)
  late Map<String,Map<String, String>> dynamicFields;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController(text: widget.initialCompanyName);
    _addressController = TextEditingController(text: widget.initialAddress);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);
    dynamicFields = Map<String,Map<String, String>>.from(widget.initialDynamicFields ?? {});
    print(dynamicFields.toString());
    img = widget.initialImg;
  }

  Future<Uint8List?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return image.readAsBytes();
    }
    return null;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Business Logo
            Material(
              elevation: 4.0,
              shadowColor: Colors.black87,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () async {
                  img = await pickImage();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(40),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: img != null ? MemoryImage(img!) : null,
                  child: img == null ? const Icon(Icons.add_photo_alternate, size: 30) : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
             Text(
              "addLogo".tr(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Company Name, Address, Email, Phone fields
            _buildTextField("companyName".tr(), 10 ,_companyNameController),
            const SizedBox(height: 8),
            _buildTextField("address".tr(), 72,_addressController, maxLines: 2),
            const SizedBox(height: 8),
            _buildTextField("email".tr(),91 ,_emailController),
            const SizedBox(height: 8),
            _buildTextField("phone".tr(),85 ,_phoneController),
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
                  _companyNameController.text,
                  _addressController.text,
                  _emailController.text,
                  _phoneController.text,
                  dynamicFields,
                  img,
                );
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child:  Text("save".tr(), style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to build text fields
  Widget _buildTextField(String label,double size, TextEditingController controller, {int maxLines = 1}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
         SizedBox(width: size),
        Expanded(
          child: TextField(
            maxLines: maxLines,
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
