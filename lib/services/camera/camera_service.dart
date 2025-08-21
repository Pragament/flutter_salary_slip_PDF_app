import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  List<CameraDescription>? cameras;
  CameraController? controller;
  bool _isInitialized = false;

  bool get isInitialized =>
      _isInitialized && controller?.value.isInitialized == true;

  Future<void> initialize() async {
    if (_isInitialized &&
        controller != null &&
        controller!.value.isInitialized) {
      // Already initialized
      return;
    }

    // Release any existing controller
    await disposeCamera();

    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      throw Exception('Camera permission denied');
    }

    // Get available cameras
    cameras = await availableCameras();
    if (cameras == null || cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    // Initialize the controller with the front camera
    final frontCamera = cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras!.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller!.initialize();

      // Optimize camera settings for face recognition
      try {
        if (controller!.value.exposureMode != ExposureMode.auto) {
          await controller!.setExposureMode(ExposureMode.auto);
        }
        if (controller!.value.focusMode != FocusMode.auto) {
          await controller!.setFocusMode(FocusMode.auto);
        }
      } catch (e) {
        debugPrint('Warning: Could not set optimal camera parameters: $e');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      await disposeCamera();
      throw Exception('Failed to initialize camera: $e');
    }
  }

  Future<String?> takePicture() async {
    if (!_isInitialized || controller == null) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Failed to initialize camera before taking picture: $e');
        return null;
      }
    }

    try {
      // Capture the image
      final XFile image = await controller!.takePicture();

      // Create a unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir =
          Directory(path.join(directory.path, 'attendance_images'));

      // Ensure directory exists
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Save image to app documents directory with unique name
      final newImagePath =
          path.join(imagesDir.path, 'attendance_$timestamp.jpg');
      await File(image.path).copy(newImagePath);

      // Delete the original temporary file
      try {
        await File(image.path).delete();
      } catch (e) {
        debugPrint('Warning: Could not delete temp image: $e');
      }

      return newImagePath;
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }

  Future<void> disposeCamera() async {
    if (controller != null) {
      await controller!.dispose();
      controller = null;
    }
    _isInitialized = false;
  }
}

// Provider for the camera service
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() {
    service.disposeCamera();
  });
  return service;
});
