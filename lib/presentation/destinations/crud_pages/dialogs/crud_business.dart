import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class ManageBusinessPage extends StatefulWidget {
  final String title;
  final String? initialCompanyName;
  final String? initialAddress;
  final String? initialEmail;
  final String? initialPhone;
  final Uint8List? initialImg;
  final Map<String, String>? initialDynamicFields;
  final void Function(String companyName, String address, String email, String phone,
      Map<String, String> dynamicFields, Uint8List? image) onSubmit;

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
  late Map<String, TextEditingController> _dynamicFieldControllers;
  Uint8List? img;

  @override
  void initState() {
    super.initState();
    _companyNameController = TextEditingController(text: widget.initialCompanyName);
    _addressController = TextEditingController(text: widget.initialAddress);
    _emailController = TextEditingController(text: widget.initialEmail);
    _phoneController = TextEditingController(text: widget.initialPhone);

    // Initialize controllers for dynamic fields
    _dynamicFieldControllers = {
      for (var entry in (widget.initialDynamicFields ?? {}).entries)
        entry.key: TextEditingController(text: entry.value),
    };

    img = widget.initialImg;
    print("init : "+img.toString());
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

    // Dispose dynamic field controllers
    for (var controller in _dynamicFieldControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<Uint8List?> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      return image.readAsBytes();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Column(
                children: [
                  Material(
                    elevation: 4.0, // Set the elevation for the shadow
                    shadowColor: Colors.black87, // Set the shadow color
                    shape: const CircleBorder(), // Ensure the shape is circular
                    child: InkWell(
                      onTap: () async {
                        img = await pickImage();
                        print(img.toString());
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(40), // Ensure the tap area is circular
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: img != null
                            ? MemoryImage(img!) // Set the image as the background
                            : null,
                        child: img == null
                            ? const Icon(Icons.add_photo_alternate, size: 30)
                            : null, // Hide the icon when an image is set
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Text(
                    "Add Business Logo",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  "Company Name",
                  style: TextStyle(fontSize: 16),
                ),
                const Text(
                  "*",
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _companyNameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  "Address",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 85),
                Expanded(
                  child: TextField(
                    maxLines: 2,
                    controller: _addressController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  "Email",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 105),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  "Phone",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 98),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
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
                          onChanged: (value) {
                            setState(() {
                              String oldValue = key;
                              String? content = _dynamicFieldControllers.remove(oldValue)?.text;
                              _dynamicFieldControllers[value] =
                                  TextEditingController(text: content);
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
              label: const Text("Add Custom Field", style: TextStyle(color: Colors.white)),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            widget.onSubmit(
              _companyNameController.text,
              _addressController.text,
              _emailController.text,
              _phoneController.text,
              {
                for (var entry in _dynamicFieldControllers.entries) entry.key: entry.value.text,
              },
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
          child: const Text("SAVE", style: TextStyle(fontSize: 18, color: Colors.white)),
        ),
      ),
    );
  }
}
