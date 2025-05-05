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
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
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
    );
    
    await controller!.initialize();
    _isInitialized = true;
  }
  
  Future<String?> takePicture() async {
    if (!_isInitialized || controller == null) {
      await initialize();
    }
    
    try {
      // Capture the image
      final XFile image = await controller!.takePicture();
      
      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(directory.path, 'attendance_images', fileName);
      
      // Create directory if it doesn't exist
      final imageDir = Directory(path.dirname(filePath));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      
      // Copy the image to the new path
      final File newFile = File(filePath);
      await File(image.path).copy(filePath);
      
      return filePath;
    } catch (e) {
      print('Error taking picture: $e');
      return null;
    }
  }
  
  void disposeCamera() {
    if (controller != null) {
      controller!.dispose();
      _isInitialized = false;
    }
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