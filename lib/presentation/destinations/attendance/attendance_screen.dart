import 'dart:io';
import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../services/base/database/hive_manager/models.dart';
import '../../../services/providers/attendance_provider.dart';
import '../../../services/providers/emp_provider.dart';
import '../../../services/providers/cur_group_provider.dart';
import '../../../services/providers/cur_branch_provider.dart';
import '../../../services/providers/cur_org_provider.dart';
import '../camera/camera_screen.dart';
import 'face_recognition_widget.dart';
import '../../../services/face_recognition/face_recognition_service.dart';

// Result class for the face verification failure dialog
class VerificationDialogResult {
  final bool proceed;
  final String? notes;

  VerificationDialogResult({required this.proceed, this.notes});
}

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with WidgetsBindingObserver {
  String? selectedEmployeeId;
  String? recognizedEmployeeId;
  bool isLoading = false;
  bool isFaceRecognitionActive = true;
  bool permissionsGranted = false;
  bool isCheckingPermissions = false;
  Map<String, dynamic> recognitionStats = {};
  bool isProcessingAttendance = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndInitialize();
    _cleanupUnusedResources();

    // Ensure employees are loaded when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureEmployeesLoaded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // This will run when dependencies (like providers) change
    _ensureEmployeesLoaded();
  }

  Future<void> _ensureEmployeesLoaded() async {
    final employees = ref.read(employeeProvider);
    if (employees == null || employees.isEmpty) {
      // Force reload employees
      await ref.read(employeeProvider.notifier).reloadEmployees();
      print('Employees reloaded in attendance screen');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage camera resources
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground - reinitialize face recognition
      _reinitializeFaceRecognition();
      // Also ensure employees are loaded
      _ensureEmployeesLoaded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - clean up resources
      _cleanupFaceRecognitionResources();
    }
  }

  Future<void> _cleanupFaceRecognitionResources() async {
    if (!mounted) return;

    try {
      final faceService = ref.read(faceRecognitionServiceProvider);
      // Force face service to release resources
      await faceService.forceDispose();
    } catch (e) {
      debugPrint('Error cleaning up face recognition resources: $e');
    }
  }

  Future<void> _reinitializeFaceRecognition() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final faceService = ref.read(faceRecognitionServiceProvider);

      // Force reset face service
      await faceService.forceDispose();

      // Short delay to ensure resources are released
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Reinitialize face recognition
      await _initializeFaceRecognition();

      setState(() {
        // Reset face recognition active state
        isFaceRecognitionActive = true;
      });
    } catch (e) {
      debugPrint('Error reinitializing face recognition: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Method to clean up resources
  void _cleanupUnusedResources() {
    // Clear caches and unused files
    _cleanupOldImageFiles();
  }

  // Method to clean up old image files
  Future<void> _cleanupOldImageFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final attendanceImagesDir =
          Directory(path.join(directory.path, 'attendance_images'));

      // If directory doesn't exist, nothing to clean
      if (!await attendanceImagesDir.exists()) return;

      // Get all files in the directory
      final files = await attendanceImagesDir.list().toList();

      // Sort by last modified time
      files.sort((a, b) {
        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return bTime.compareTo(aTime); // Newest first
      });

      // Keep the most recent 50 files, delete the rest
      if (files.length > 50) {
        for (int i = 50; i < files.length; i++) {
          try {
            await (files[i] as File).delete();
          } catch (e) {
            debugPrint('Error deleting old file: $e');
          }
        }
        debugPrint('Deleted ${files.length - 50} old attendance images');
      }
    } catch (e) {
      debugPrint('Error cleaning up old images: $e');
    }
  }

  Future<void> _checkPermissionsAndInitialize() async {
    if (isCheckingPermissions) return;

    setState(() {
      isLoading = true;
      isCheckingPermissions = true;
    });

    try {
      final cameraStatus = await Permission.camera.status;

      bool needsPermissions = false;
      if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied) {
        needsPermissions = true;
      }

      if (needsPermissions) {
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          if (Platform.isAndroid) Permission.storage,
        ].request();

        final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;

        if (!cameraGranted) {
          setState(() {
            permissionsGranted = false;
            isCheckingPermissions = false;
          });
          _showPermissionDialog();
          return;
        }
      }

      setState(() {
        permissionsGranted = true;
        isCheckingPermissions = false;
      });

      await _loadInitialData();
    } catch (e) {
      setState(() {
        isCheckingPermissions = false;
      });
      _showErrorSnackBar('Failed to check permissions: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isCheckingPermissions = false;
        });
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text(
            'This app needs camera access to:\n'
            '• Take attendance photos\n'
            '• Perform face recognition\n\n'
            'Please grant camera permission to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/');
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                final cameraStatus = await Permission.camera.status;
                if (cameraStatus.isPermanentlyDenied) {
                  await openAppSettings();
                } else {
                  _checkPermissionsAndInitialize();
                }
              },
              child: const Text('Grant Permission'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadInitialData() async {
    if (!permissionsGranted) return;

    try {
      final currentOrg = ref.read(currentOrganizationProvider);
      final currentBranch = ref.read(currentBranchProvider);
      final currentGroup = ref.read(currentGroupProvider);

      if (currentOrg != null && currentBranch != null && currentGroup != null) {
        await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
            currentOrg.id, currentBranch.id, currentGroup.id);

        await _initializeFaceRecognition();

        final faceService = ref.read(faceRecognitionServiceProvider);
        setState(() {
          recognitionStats = faceService.getRecognitionStats();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load attendance data: $e');
    }
  }

  Future<void> _initializeFaceRecognition() async {
    try {
      final faceService = ref.read(faceRecognitionServiceProvider);
      await faceService.loadStoredFaceRegistrations();

      final stats = faceService.getRecognitionStats();
      debugPrint(
          'Face recognition initialized: ${stats['totalEmployees']} registered employees');
    } catch (e) {
      debugPrint('Error initializing face recognition: $e');
    }
  }

  void _onEmployeeDetected(String? employeeId) {
    if (employeeId == null || !mounted || isProcessingAttendance) return;

    final employees = ref.read(employeeProvider) ?? [];
    final detectedEmployee =
        employees.where((emp) => emp.id == employeeId).firstOrNull;

    if (detectedEmployee == null) {
      return;
    }

    if (selectedEmployeeId != employeeId) {
      setState(() {
        selectedEmployeeId = employeeId;
        recognizedEmployeeId = employeeId;
      });

      _showSnackBar('Employee detected: ${detectedEmployee.name}',
          isSuccess: true);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: isSuccess ? 2 : 3),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    _showSnackBar(message, isSuccess: false);
  }

  // Smart retry for face recognition when employee detection is slow
  Future<void> _smartRetryFaceRecognition() async {
    if (!mounted) return;

    final currentFaceService = ref.read(faceRecognitionServiceProvider);

    // If the service is healthy, just reset error counters
    if (currentFaceService.isHealthy()) {
      currentFaceService.resetErrorCounters();
      _showSnackBar('Face recognition optimized', isSuccess: true);
      return;
    }

    // Otherwise do a full restart
    setState(() {
      isLoading = true;
    });

    try {
      await currentFaceService.forceDispose();

      // Small delay to ensure clean shutdown
      await Future.delayed(const Duration(milliseconds: 300));

      // Re-initialize face recognition
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        await currentFaceService.initialize(cameras);
        await currentFaceService.loadStoredFaceRegistrations();
      }

      _showSnackBar('Face recognition restarted', isSuccess: true);
    } catch (e) {
      _showErrorSnackBar('Failed to restart face recognition: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Dialog shown when verification fails, with option to continue
  Future<VerificationDialogResult> _showFaceVerificationFailureDialog({
    required String message,
    bool allowOverride = true,
    required bool isSamePersonLikely,
  }) async {
    final TextEditingController notesController = TextEditingController();

    final result = await showDialog<VerificationDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          // Add scroll view to prevent overflow
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Verification Failed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Possible reasons:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text('• Poor lighting conditions'),
                Text('• Face not clearly visible'),
                Text('• Appearance changed (beard, glasses, etc.)'),
                if (!isSamePersonLikely)
                  Text('• This may not be the same person',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                if (allowOverride && isSamePersonLikely) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Would you like to continue anyway?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'This will be recorded in the attendance log.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Notes (required for override)',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      hintText: 'Example: New glasses',
                      isDense: true, // Reduces the height of the TextField
                    ),
                    maxLines: 2,
                    minLines: 1,
                    style: TextStyle(fontSize: 14),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(VerificationDialogResult(
                          proceed: false,
                          notes: null,
                        ));
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    if (allowOverride && isSamePersonLikely)
                      ElevatedButton(
                        onPressed: () {
                          if (notesController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Please add a note explaining the override'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).pop(VerificationDialogResult(
                            proceed: true,
                            notes:
                                'MANUAL OVERRIDE: ${notesController.text.trim()}',
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('Continue Anyway'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return result ?? VerificationDialogResult(proceed: false);
  }

  // This method checks if the selected employee matches the recognized employee
  bool _isSelectionConsistentWithRecognition() {
    // If there's no recognized employee, no consistency to check
    if (recognizedEmployeeId == null) return true;

    // If the selected employee is the same as the recognized one, that's consistent
    return selectedEmployeeId == recognizedEmployeeId;
  }

  Future<void> _handlePunchIn() async {
    if (isProcessingAttendance) return;

    if (!permissionsGranted) {
      _checkPermissionsAndInitialize();
      return;
    }

    if (selectedEmployeeId == null) {
      _showErrorSnackBar('Please select an employee first');
      return;
    }

    // Security check: If we have recognized an employee via face detection,
    // only allow punch-in for that specific employee
    bool isSamePersonLikely = _isSelectionConsistentWithRecognition();
    if (!isSamePersonLikely && recognizedEmployeeId != null) {
      final employees = ref.read(employeeProvider) ?? [];
      final selectedEmployee = employees.firstWhere(
        (e) => e.id == selectedEmployeeId,
        orElse: () => Employee('Unknown', '', '', {}, selectedEmployeeId!),
      );
      final recognizedEmployee = employees.firstWhere(
        (e) => e.id == recognizedEmployeeId,
        orElse: () => Employee('Unknown', '', '', {}, recognizedEmployeeId!),
      );

      _showErrorSnackBar(
          'Cannot punch in: Face recognition detected ${recognizedEmployee.name} but you selected ${selectedEmployee.name}');
      return;
    }

    final currentOrg = ref.read(currentOrganizationProvider);
    final currentBranch = ref.read(currentBranchProvider);
    final currentGroup = ref.read(currentGroupProvider);

    if (currentOrg == null || currentBranch == null || currentGroup == null) {
      _showErrorSnackBar('Organization, branch, or group not selected');
      return;
    }

    setState(() {
      isProcessingAttendance = true;
    });

    try {
      // Check if employee already has an active session
      final latestLog = await ref
          .read(attendanceProvider.notifier)
          .getLatestAttendanceLog(currentOrg.id, currentBranch.id,
              currentGroup.id, selectedEmployeeId!);

      if (latestLog != null && latestLog.punchOutTime == null) {
        _showErrorSnackBar('This employee is already punched in');
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      // Show information dialog before starting
      final proceedWithCamera = await _showPunchInInfoDialog();
      if (proceedWithCamera != true) {
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      // Open camera for punch-in selfie
      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(
            title: 'Punch In Selfie',
          ),
        ),
      );

      if (imagePath == null) {
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      setState(() {
        isLoading = true;
      });

      // Validate face in photo against selected employee
      final faceService = ref.read(faceRecognitionServiceProvider);
      final isValidFace = await faceService.validateEmployeeFaceForAttendance(
          selectedEmployeeId!, imagePath);

      // If face verification fails, give option to continue anyway
      bool proceedWithPunchIn = isValidFace;
      String? notes;

      if (!isValidFace) {
        // Show a dialog offering to continue with a note
        final manualOverride = await _showFaceVerificationFailureDialog(
          message:
              'Face verification failed. The person in the photo does not match the registered face.',
          allowOverride: true,
          isSamePersonLikely:
              true, // Allow override for same employee's failed verification
        );

        if (manualOverride.proceed) {
          proceedWithPunchIn = true;
          notes = manualOverride.notes;
        } else {
          // User chose not to override
          try {
            await File(imagePath).delete();
          } catch (e) {
            debugPrint('Error deleting invalid image: $e');
          }
          setState(() {
            isLoading = false;
            isProcessingAttendance = false;
          });
          return;
        }
      }

      if (proceedWithPunchIn) {
        // Proceed with punch-in, recording verification status
        await ref.read(attendanceProvider.notifier).punchIn(
            currentOrg.id,
            currentBranch.id,
            currentGroup.id,
            selectedEmployeeId!,
            imagePath,
            notes,
            faceVerified: isValidFace);

        String message = isValidFace
            ? 'Successfully punched in!'
            : 'Punched in (manual override - face verification failed)';
        _showSnackBar(message);

        // Use the image to improve face recognition if verification failed
        if (!isValidFace && imagePath != null) {
          try {
            // Register this face image for improved recognition
            // We'll add it with lower confidence
            await faceService.registerEmployeeFaceWithLowerConfidence(
                selectedEmployeeId!, imagePath);
          } catch (e) {
            debugPrint('Error updating face recognition: $e');
          }
        }

        // Refresh logs
        await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
            currentOrg.id, currentBranch.id, currentGroup.id);

        // Ensure employees are loaded
        await _ensureEmployeesLoaded();

        // Clean up resources after successful operation
        _cleanupUnusedResources();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to punch in: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isProcessingAttendance = false;
        });
      }
    }
  }

  // Dialog to show before starting punch-in process
  Future<bool?> _showPunchInInfoDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Punch In'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to punch in:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Employee?>(
              future: _getSelectedEmployee(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final employee = snapshot.data;
                return Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employee?.name ?? 'Selected Employee',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Please note:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('• The system will verify your face'),
            Text('• Look directly at the camera'),
            Text('• Ensure good lighting'),
            if (recognizedEmployeeId != null &&
                selectedEmployeeId == recognizedEmployeeId) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Face already verified',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<Employee?> _getSelectedEmployee() async {
    if (selectedEmployeeId == null) return null;
    final employees = ref.read(employeeProvider) ?? [];
    return employees.firstWhere(
      (emp) => emp.id == selectedEmployeeId,
      orElse: () => Employee('Unknown', '', '', {}, selectedEmployeeId!),
    );
  }

  // Improved punch-out with validation and feedback
  Future<void> _handlePunchOut() async {
    if (isProcessingAttendance) return;

    if (!permissionsGranted) {
      _checkPermissionsAndInitialize();
      return;
    }

    if (selectedEmployeeId == null) {
      _showErrorSnackBar('Please select an employee first');
      return;
    }

    // Security check: If we have recognized an employee via face detection,
    // only allow punch-out for that specific employee
    bool isSamePersonLikely = _isSelectionConsistentWithRecognition();
    if (!isSamePersonLikely && recognizedEmployeeId != null) {
      final employees = ref.read(employeeProvider) ?? [];
      final selectedEmployee = employees.firstWhere(
        (e) => e.id == selectedEmployeeId,
        orElse: () => Employee('Unknown', '', '', {}, selectedEmployeeId!),
      );
      final recognizedEmployee = employees.firstWhere(
        (e) => e.id == recognizedEmployeeId,
        orElse: () => Employee('Unknown', '', '', {}, recognizedEmployeeId!),
      );

      _showErrorSnackBar(
          'Cannot punch out: Face recognition detected ${recognizedEmployee.name} but you selected ${selectedEmployee.name}');
      return;
    }

    final currentOrg = ref.read(currentOrganizationProvider);
    final currentBranch = ref.read(currentBranchProvider);
    final currentGroup = ref.read(currentGroupProvider);

    if (currentOrg == null || currentBranch == null || currentGroup == null) {
      _showErrorSnackBar('Organization, branch, or group not selected');
      return;
    }

    setState(() {
      isProcessingAttendance = true;
    });

    try {
      // Get the latest attendance log for this employee
      final latestLog = await ref
          .read(attendanceProvider.notifier)
          .getLatestAttendanceLog(currentOrg.id, currentBranch.id,
              currentGroup.id, selectedEmployeeId!);

      if (latestLog == null || latestLog.punchOutTime != null) {
        _showErrorSnackBar(
            'No active attendance session found for this employee');
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      // Show information dialog before starting
      final proceedWithCamera = await _showPunchOutInfoDialog();
      if (proceedWithCamera != true) {
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      // Open camera for punch-out selfie
      final imagePath = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraScreen(
            title: 'Punch Out Selfie',
          ),
        ),
      );

      if (imagePath == null) {
        setState(() {
          isProcessingAttendance = false;
        });
        return;
      }

      setState(() {
        isLoading = true;
      });

      // Validate face in photo against selected employee
      final faceService = ref.read(faceRecognitionServiceProvider);
      final isValidFace = await faceService.validateEmployeeFaceForAttendance(
          selectedEmployeeId!, imagePath);

      // If face verification fails, give option to continue anyway
      bool proceedWithPunchOut = isValidFace;
      String? notes;

      if (!isValidFace) {
        // Show a dialog offering to continue with a note
        final manualOverride = await _showFaceVerificationFailureDialog(
          message:
              'Face verification failed. The person in the photo does not match the registered face.',
          allowOverride: true,
          isSamePersonLikely:
              true, // Allow override for same employee's failed verification
        );

        if (manualOverride.proceed) {
          proceedWithPunchOut = true;
          notes = manualOverride.notes;
        } else {
          // User chose not to override
          try {
            await File(imagePath).delete();
          } catch (e) {
            debugPrint('Error deleting invalid image: $e');
          }
          setState(() {
            isLoading = false;
            isProcessingAttendance = false;
          });
          return;
        }
      }

      if (proceedWithPunchOut) {
        // Proceed with punch-out, recording verification status
        await ref.read(attendanceProvider.notifier).punchOut(
            latestLog.id, imagePath, notes,
            faceVerified: isValidFace);

        String message = isValidFace
            ? 'Successfully punched out!'
            : 'Punched out (manual override - face verification failed)';
        _showSnackBar(message);

        // Use the image to improve face recognition if verification failed
        if (!isValidFace && imagePath != null) {
          try {
            // Register this face image for improved recognition
            await faceService.registerEmployeeFaceWithLowerConfidence(
                selectedEmployeeId!, imagePath);
          } catch (e) {
            debugPrint('Error updating face recognition: $e');
          }
        }

        // Refresh logs
        await ref.read(attendanceProvider.notifier).loadRecentAttendanceLogs(
            currentOrg.id, currentBranch.id, currentGroup.id);

        // Ensure employees are loaded
        await _ensureEmployeesLoaded();

        // Clean up resources after successful operation
        _cleanupUnusedResources();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to punch out: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isProcessingAttendance = false;
        });
      }
    }
  }

  // Dialog to show before starting punch-out process
  Future<bool?> _showPunchOutInfoDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Punch Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to punch out:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Employee?>(
              future: _getSelectedEmployee(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final employee = snapshot.data;
                return Row(
                  children: [
                    Icon(Icons.person, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        employee?.name ?? 'Selected Employee',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Please note:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('• The system will verify your face'),
            Text('• Look directly at the camera'),
            Text('• Ensure good lighting'),
            if (recognizedEmployeeId != null &&
                selectedEmployeeId == recognizedEmployeeId) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Face already verified',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // Modified to include cleanup and reinitialize
  void _toggleFaceRecognition() {
    setState(() {
      isFaceRecognitionActive = !isFaceRecognitionActive;
    });

    _showSnackBar(
      isFaceRecognitionActive
          ? 'Face recognition enabled'
          : 'Face recognition disabled',
      isSuccess: true,
    );

    // Clean up resources
    _cleanupUnusedResources();

    // If turning on, reinitialize to ensure fresh start
    if (isFaceRecognitionActive) {
      _reinitializeFaceRecognition();
    } else {
      // If turning off, release camera resources
      _cleanupFaceRecognitionResources();
    }
  }

  void _onEmployeeManuallySelected(String? employeeId) {
    setState(() {
      selectedEmployeeId = employeeId;
      if (employeeId != recognizedEmployeeId) {
        // Only clear the recognized employee if user explicitly selects a different employee
        recognizedEmployeeId = null;
      }
    });
  }

  void _goToFaceRegistration() {
    context.go('/attendance/face-registration');
  }

  void _viewAttendanceHistory() {
    context.go('/attendance/history');
  }

  // Add this method for emergency quick detection that respects security
  Future<void> _emergencyDetection() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final faceService = ref.read(faceRecognitionServiceProvider);
      final employeeId = await faceService.emergencyFastDetection();

      if (employeeId != null) {
        _onEmployeeDetected(employeeId);
        _showSnackBar('Employee detected using historical data',
            isSuccess: true);
      } else {
        _showErrorSnackBar('No employee found in recognition history');
      }
    } catch (e) {
      _showErrorSnackBar('Emergency detection failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Updated method to display attendance cards with verification status
  Widget _buildAttendanceCard(AttendanceLog log, List<Employee>? employees) {
    final employee =
        employees?.where((e) => e.id == log.employeeId).firstOrNull ??
            Employee('Unknown', '', '', {}, log.employeeId);

    final bool isActive = log.punchOutTime == null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(log.punchInTime),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'In:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                          if (log.punchInFaceVerified == false)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning,
                                color: Colors.orange[700],
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        DateFormat('h:mm a').format(log.punchInTime),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Out:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                          if (log.punchOutTime != null &&
                              log.punchOutFaceVerified == false)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.warning,
                                color: Colors.orange[700],
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        log.punchOutTime != null
                            ? DateFormat('h:mm a').format(log.punchOutTime!)
                            : '-- : --',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (log.notes != null &&
                log.notes!.contains('MANUAL OVERRIDE')) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  log.notes!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange[800],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (log.punchInImagePath != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (log.punchInImagePath != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(log.punchInImagePath!),
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 40,
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 20, color: Colors.grey[600]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (log.punchInImagePath != null &&
                      log.punchOutImagePath != null)
                    const SizedBox(width: 8),
                  if (log.punchOutImagePath != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(log.punchOutImagePath!),
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 40,
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 20, color: Colors.grey[600]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final employees = ref.watch(employeeProvider);
    final attendanceLogs = ref.watch(attendanceProvider);

    // Performance optimization
    final shouldOptimizeFaceRecognition =
        MediaQuery.of(context).size.width < 600;

    if (currentGroup == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text("attendance".tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(child: Text("noGrpSelected".tr())),
      );
    }

    if (!permissionsGranted || isCheckingPermissions) {
      return Scaffold(
        appBar: AppBar(
          title: Text("attendance".tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCheckingPermissions) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Checking permissions...'),
              ] else ...[
                const Icon(Icons.camera_alt_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Camera permission is required\nfor attendance functionality',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _checkPermissionsAndInitialize,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Grant Camera Permission'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final registeredEmployees = recognitionStats['totalEmployees'] ?? 0;
    final totalEmployees = employees?.length ?? 0;
    final needsRegistration = totalEmployees > registeredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: Text("attendance".tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          // Add emergency buttons
          IconButton(
            icon: const Icon(Icons.sync_problem),
            onPressed: _smartRetryFaceRecognition,
            tooltip: 'Fix Face Recognition',
          ),
          // Original buttons
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              _ensureEmployeesLoaded();
              _showSnackBar('Employee data refreshed');
            },
            tooltip: 'Refresh Employee Data',
          ),
          IconButton(
            icon: Icon(
              Icons.face_retouching_natural,
              color: needsRegistration ? Colors.orange : Colors.green,
            ),
            onPressed: _goToFaceRegistration,
            tooltip: 'Face Registration',
          ),
          IconButton(
            icon: Icon(
              isFaceRecognitionActive ? Icons.face : Icons.face_outlined,
              color: isFaceRecognitionActive ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleFaceRecognition,
            tooltip: isFaceRecognitionActive
                ? 'Disable face recognition'
                : 'Enable face recognition',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _viewAttendanceHistory,
            tooltip: 'View History',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reinitializeFaceRecognition,
            tooltip: 'Refresh Face Recognition',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Face registration banner
                  if (needsRegistration)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning,
                                  color: Colors.orange[600], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Face Registration Needed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _goToFaceRegistration,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Setup',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Only $registeredEmployees of $totalEmployees employees have registered faces. Register faces for automatic recognition.',
                            style: TextStyle(
                                color: Colors.orange[700], fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  // Main attendance section
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Face recognition section
                          if (registeredEmployees > 0 &&
                              employees != null &&
                              employees.isNotEmpty)
                            RepaintBoundary(
                              // Optimize rendering
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FaceRecognitionWidget(
                                        isActive: isFaceRecognitionActive,
                                        onEmployeeDetected: _onEmployeeDetected,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.face_rounded,
                                                  color: isFaceRecognitionActive
                                                      ? Colors.green
                                                      : Colors.grey,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    "Face Recognition",
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              isFaceRecognitionActive
                                                  ? "Looking for registered employee faces..."
                                                  : "Face recognition is disabled",
                                              style: TextStyle(
                                                color: isFaceRecognitionActive
                                                    ? Colors.green[700]
                                                    : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '$registeredEmployees employees registered',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            // Add emergency quick detect button for easy access
                                            if (isFaceRecognitionActive)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 8),
                                                child: ElevatedButton.icon(
                                                  onPressed:
                                                      _emergencyDetection,
                                                  icon: Icon(Icons.bolt,
                                                      size: 16),
                                                  label: Text('Quick Detect',
                                                      style: TextStyle(
                                                          fontSize: 12)),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.orange,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2),
                                                    minimumSize: Size(0, 30),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),

                          // Employee selector
                          Row(
                            children: [
                              Icon(Icons.person_rounded,
                                  color: Colors.blue[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Select Employee",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Add employee data status indicator for debugging
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: employees == null || employees.isEmpty
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: employees == null || employees.isEmpty
                                    ? Colors.red.shade200
                                    : Colors.green.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  employees == null || employees.isEmpty
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  size: 16,
                                  color: employees == null || employees.isEmpty
                                      ? Colors.red
                                      : Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    employees == null
                                        ? 'Employee data not loaded yet'
                                        : employees.isEmpty
                                            ? 'No employees found - tap reload'
                                            : '${employees.length} employees loaded',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          employees == null || employees.isEmpty
                                              ? Colors.red.shade800
                                              : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                                if (employees == null || employees.isEmpty)
                                  TextButton.icon(
                                    onPressed: _ensureEmployeesLoaded,
                                    icon: const Icon(Icons.refresh, size: 14),
                                    label: const Text('Reload',
                                        style: TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              suffixIcon: recognizedEmployeeId != null &&
                                      selectedEmployeeId == recognizedEmployeeId
                                  ? Icon(Icons.face,
                                      color: Colors.green[600], size: 20)
                                  : null,
                            ),
                            isExpanded: true,
                            hint: const Text('Choose an employee',
                                style: TextStyle(fontSize: 14)),
                            value: selectedEmployeeId,
                            items: employees?.map((employee) {
                                  return DropdownMenuItem<String>(
                                    value: employee.id,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            employee.name,
                                            style:
                                                const TextStyle(fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (recognizedEmployeeId == employee.id)
                                          Icon(Icons.face,
                                              color: Colors.green[600],
                                              size: 16),
                                      ],
                                    ),
                                  );
                                }).toList() ??
                                [],
                            onChanged: _onEmployeeManuallySelected,
                          ),
                          if (recognizedEmployeeId != null &&
                              selectedEmployeeId == recognizedEmployeeId)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[600], size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Automatically detected',
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Recent attendance section
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: attendanceLogs == null || attendanceLogs.isEmpty
                        ? Center(child: Text("noAttendanceRecords".tr()))
                        : _buildRecentAttendanceList(attendanceLogs, employees),
                  ),
                ],
              ),
            ),
      floatingActionButton: selectedEmployeeId != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'punch_in',
                  onPressed: isProcessingAttendance ? null : _handlePunchIn,
                  backgroundColor:
                      isProcessingAttendance ? Colors.grey : Colors.green,
                  icon: isProcessingAttendance
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Punch In'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'punch_out',
                  onPressed: isProcessingAttendance ? null : _handlePunchOut,
                  backgroundColor:
                      isProcessingAttendance ? Colors.grey : Colors.red,
                  icon: isProcessingAttendance
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: const Text('Punch Out'),
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () =>
                  _showErrorSnackBar('Please select an employee first'),
              backgroundColor: Colors.grey,
              icon: const Icon(Icons.person_add),
              label: const Text('Select Employee'),
            ),
    );
  }

  Widget _buildRecentAttendanceList(
      List<AttendanceLog> logs, List<Employee>? employees) {
    final filteredLogs = selectedEmployeeId != null
        ? logs.where((log) => log.employeeId == selectedEmployeeId).toList()
        : logs;

    filteredLogs.sort((a, b) => b.punchInTime.compareTo(a.punchInTime));
    final recentLogs = filteredLogs.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Recent Attendance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: recentLogs.isEmpty
              ? const Center(child: Text('No recent attendance records'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: recentLogs.length,
                  itemBuilder: (context, index) {
                    return _buildAttendanceCard(recentLogs[index], employees);
                  },
                ),
        ),
      ],
    );
  }
}
