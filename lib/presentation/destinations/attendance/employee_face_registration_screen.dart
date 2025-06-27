import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/providers/emp_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../../../services/face_recognition/face_recognition_service.dart';
import '../camera/camera_screen.dart';

class EmployeeFaceRegistrationScreen extends ConsumerStatefulWidget {
  const EmployeeFaceRegistrationScreen({super.key});

  @override
  ConsumerState<EmployeeFaceRegistrationScreen> createState() =>
      _EmployeeFaceRegistrationScreenState();
}

class _EmployeeFaceRegistrationScreenState
    extends ConsumerState<EmployeeFaceRegistrationScreen> {
  Map<String, List<String>> employeeFaceImages = {};
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingFaceData();
  }

  Future<void> _loadExistingFaceData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final faceService = ref.read(faceRecognitionServiceProvider);
      await faceService.loadStoredFaceRegistrations();

      final employees = ref.read(employeeProvider) ?? [];
      for (final employee in employees) {
        final images = await faceService.getEmployeeFaceImages(employee.id);
        if (images.isNotEmpty) {
          employeeFaceImages[employee.id] = images;
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load face data: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _registerEmployeeFace(Employee employee) async {
    try {
      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            title: 'Register ${employee.name}\'s Face',
          ),
        ),
      );

      if (imagePath == null) return;

      setState(() {
        isLoading = true;
      });

      final faceService = ref.read(faceRecognitionServiceProvider);
      final success =
          await faceService.registerEmployeeFace(employee.id, imagePath);

      if (success) {
        // Reload the face images to get the updated list
        await _loadExistingFaceData();
        _showSnackBar('Face registered successfully for ${employee.name}');
      } else {
        _showErrorSnackBar('Failed to register face - no clear face detected');
        try {
          await File(imagePath).delete();
        } catch (e) {
          debugPrint('Error deleting failed image: $e');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error registering face: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteEmployeeFace(String employeeId, String imagePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Face Registration'),
        content: const Text(
            'Are you sure you want to delete this face registration?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        isLoading = true;
      });

      try {
        final faceService = ref.read(faceRecognitionServiceProvider);
        await faceService.deleteEmployeeFaceImage(employeeId, imagePath);

        // Reload the face images to get the updated list
        await _loadExistingFaceData();
        _showSnackBar('Face registration deleted');
      } catch (e) {
        _showErrorSnackBar('Failed to delete face registration: $e');
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _testFaceRecognition() async {
    try {
      // First check if there are any registered faces
      final faceService = ref.read(faceRecognitionServiceProvider);
      final registeredCount = faceService.getActualRegisteredEmployeeCount();

      if (registeredCount == 0) {
        _showErrorSnackBar(
            'No faces registered yet. Register some faces first to test recognition.');
        return;
      }

      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(
            title: 'Test Face Recognition',
          ),
        ),
      );

      if (imagePath == null) return;

      setState(() {
        isLoading = true;
      });

      // Use the existing processImageForRecognition method which is more reliable
      String? recognizedEmployeeId;
      try {
        // Create a temporary image and process it
        recognizedEmployeeId = await faceService.processImageForRecognition();

        // If that doesn't work, try direct image processing
        if (recognizedEmployeeId == null) {
          // This is a workaround - we'll implement a simple test method
          recognizedEmployeeId = await _testImageRecognition(imagePath);
        }
      } catch (e) {
        debugPrint('Error in face recognition test: $e');
      }

      // Clean up test image
      try {
        await File(imagePath).delete();
      } catch (e) {
        debugPrint('Error deleting test image: $e');
      }

      if (recognizedEmployeeId != null) {
        final employees = ref.read(employeeProvider) ?? [];
        final employee =
            employees.where((e) => e.id == recognizedEmployeeId).firstOrNull;
        _showSnackBar('Recognized: ${employee?.name ?? 'Unknown Employee'}');
      } else {
        _showErrorSnackBar(
            'No employee recognized. Try taking a clearer photo or ensure the person is registered.');
      }
    } catch (e) {
      _showErrorSnackBar('Test failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Simple test method that validates an image against registered faces
  Future<String?> _testImageRecognition(String imagePath) async {
    try {
      final faceService = ref.read(faceRecognitionServiceProvider);
      final employees = ref.read(employeeProvider) ?? [];

      // Test validation against each registered employee
      for (final employee in employees) {
        final isValid = await faceService.validateEmployeeFaceForAttendance(
            employee.id, imagePath);
        if (isValid) {
          return employee.id;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error in test image recognition: $e');
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final employees = ref.watch(employeeProvider);

    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face Registration'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/attendance'),
          ),
        ),
        body: const Center(child: Text('No group selected')),
      );
    }

    // Calculate actual statistics
    final totalEmployees = employees?.length ?? 0;
    final registeredEmployees = employeeFaceImages.keys.length;
    final pendingEmployees = totalEmployees - registeredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Face Registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/attendance'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: _testFaceRecognition,
            tooltip: 'Test Face Recognition',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExistingFaceData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : employees == null || employees.isEmpty
              ? const Center(child: Text('No employees found'))
              : Column(
                  children: [
                    // Info banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'Face Registration Setup',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Register employee faces here for automatic recognition during attendance. Each employee needs at least 1 face photo, but 2-3 photos from different angles work better.',
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),

                    // Statistics
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            'Total Employees',
                            totalEmployees.toString(),
                            Icons.people,
                            Colors.blue.shade600,
                          ),
                          _buildStat(
                            'Registered',
                            registeredEmployees.toString(),
                            Icons.face,
                            Colors.green.shade600,
                          ),
                          _buildStat(
                            'Pending',
                            pendingEmployees.toString(),
                            Icons.pending,
                            Colors.orange.shade600,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Employee list
                    Expanded(
                      child: ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final employee = employees[index];
                          final faceImages =
                              employeeFaceImages[employee.id] ?? [];
                          final isRegistered = faceImages.isNotEmpty;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isRegistered ? Colors.green : Colors.orange,
                                child: Icon(
                                  isRegistered
                                      ? Icons.face
                                      : Icons.face_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                employee.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                isRegistered
                                    ? '${faceImages.length} face(s) registered'
                                    : 'No faces registered',
                                style: TextStyle(
                                  color: isRegistered
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () =>
                                    _registerEmployeeFace(employee),
                                icon: const Icon(Icons.camera_alt, size: 18),
                                label: Text(
                                    isRegistered ? 'Add More' : 'Register'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isRegistered ? Colors.blue : Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              children: [
                                if (faceImages.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Registered Face Photos:',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: faceImages.map((imagePath) {
                                            return Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(imagePath),
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                        error, stackTrace) {
                                                      return Container(
                                                        width: 80,
                                                        height: 80,
                                                        color: Colors.grey[300],
                                                        child: const Icon(
                                                            Icons.error),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 4,
                                                  right: 4,
                                                  child: GestureDetector(
                                                    onTap: () =>
                                                        _deleteEmployeeFace(
                                                            employee.id,
                                                            imagePath),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.close,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _testFaceRecognition,
        icon: const Icon(Icons.science),
        label: const Text('Test Recognition'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
