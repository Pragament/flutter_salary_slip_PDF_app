import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
// import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../base/database/hive_manager/models.dart';

class FaceRecognitionService {
  // Add these threshold constants
  final double _baseSimilarityThreshold = 0.55; // Reduced from 0.60 to 0.55
  final double _verificationThreshold = 0.60; // Reduced from 0.65 to 0.60

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    ),
  );

  bool _isBusy = false;
  CameraController? _cameraController;
  bool _isInitialized = false;
  DateTime? _lastProcessTime;
  int _consecutiveErrors = 0;
  final int _maxConsecutiveErrors = 3;

  // Store face encodings for registered employees only
  final Map<String, List<List<double>>> _registeredFaceEncodings = {};
  final Map<String, List<String>> _registeredFaceImages = {};

  // Store recognition history for better confidence tracking
  final Map<String, DateTime> _lastRecognitionTime = {};
  final Map<String, int> _recognitionSuccessCount = {};

  // Cache the most recently recognized employee to speed up repeated recognitions
  String? _cachedRecognizedEmployeeId;
  DateTime? _cachedRecognitionTime;

  // Getters
  bool get isInitialized =>
      _isInitialized &&
      _cameraController != null &&
      _cameraController!.value.isInitialized;
  bool get isBusy => _isBusy;
  int get employeeCount => _registeredFaceEncodings.keys.length;
  CameraController? get cameraController => _cameraController;

  int getActualRegisteredEmployeeCount() {
    return _registeredFaceEncodings.keys.length;
  }

  Future<void> forceDispose() async {
    try {
      _isBusy = true;

      _consecutiveErrors = 0;

      if (_cameraController != null) {
        try {
          if (_cameraController!.value.isInitialized) {
            await _cameraController!.stopImageStream();
          }
          await _cameraController!.dispose();
        } catch (e) {
          debugPrint('Error disposing camera controller: $e');
        }
        _cameraController = null;
      }

      try {
        await _faceDetector.close();
      } catch (e) {
        debugPrint('Error closing face detector: $e');
      }

      _isInitialized = false;
      _isBusy = false;
    } catch (e) {
      debugPrint('Error in force dispose: $e');
      _isInitialized = false;
      _isBusy = false;
    }
  }

  // Initialize the service
  Future<void> initialize(List<CameraDescription> cameras) async {
    if (_isInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      debugPrint('Face recognition service already initialized');
      return;
    }

    try {
      // Force clean disposal first to prevent resource leaks
      await forceDispose();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('Initializing camera: ${camera.name}');

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Optimize camera settings for face detection
      try {
        if (_cameraController!.value.exposureMode != ExposureMode.auto) {
          await _cameraController!.setExposureMode(ExposureMode.auto);
        }
        if (_cameraController!.value.focusMode != FocusMode.auto) {
          await _cameraController!.setFocusMode(FocusMode.auto);
        }

        // On some devices, we can set flash mode
        if (_cameraController!.value.flashMode != FlashMode.off) {
          await _cameraController!.setFlashMode(FlashMode.off);
        }
      } catch (e) {
        debugPrint('Warning: Could not set optimal camera parameters: $e');
      }

      await _testCamera();

      _isInitialized = true;
      _consecutiveErrors = 0;

      // Reset any stale processing state
      _isBusy = false;

      debugPrint('Face recognition camera initialized successfully');
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      _isInitialized = false;
      await _disposeController();
      rethrow;
    }
  }

  Future<void> _testCamera() async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized)
        return;

      final XFile testImage = await _cameraController!.takePicture();
      await File(testImage.path).delete();
      debugPrint('Camera test successful');
    } catch (e) {
      debugPrint('Camera test failed: $e');
      throw Exception('Camera test failed: $e');
    }
  }

  Future<void> _disposeController() async {
    try {
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      debugPrint('Error disposing camera controller: $e');
    }
  }

  // Add this method for faster but less accurate detection
  Future<String?> emergencyFastDetection() async {
    if (_registeredFaceEncodings.isEmpty) return null;

    // Get most recently recognized employee
    String? mostRecentEmployeeId;
    DateTime? mostRecentTime;

    for (final entry in _lastRecognitionTime.entries) {
      if (mostRecentTime == null || entry.value.isAfter(mostRecentTime)) {
        mostRecentTime = entry.value;
        mostRecentEmployeeId = entry.key;
      }
    }

    if (mostRecentEmployeeId != null && mostRecentTime != null) {
      // If we've seen someone in the last 2 minutes, just return them
      if (DateTime.now().difference(mostRecentTime).inMinutes < 2) {
        debugPrint(
            'Emergency detection returning most recent employee: $mostRecentEmployeeId');
        return mostRecentEmployeeId;
      }
    }

    // If no recent detection, return the most frequently recognized employee
    String? mostFrequentEmployeeId;
    int maxCount = 0;

    for (final entry in _recognitionSuccessCount.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostFrequentEmployeeId = entry.key;
      }
    }

    if (mostFrequentEmployeeId != null && maxCount > 3) {
      debugPrint(
          'Emergency detection returning most frequent employee: $mostFrequentEmployeeId');
      return mostFrequentEmployeeId;
    }

    return null;
  }

  Future<String?> processImageForRecognition() async {
    final now = DateTime.now();

    // Check cache first for quick return - MORE AGGRESSIVE CACHING
    if (_cachedRecognizedEmployeeId != null && _cachedRecognitionTime != null) {
      // If we recognized someone in the last 5 seconds, return them immediately (increased from 2s)
      if (now.difference(_cachedRecognitionTime!).inSeconds < 5) {
        return _cachedRecognizedEmployeeId;
      }
    }

    // Reduce rate limiting to 200ms instead of 300ms
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!).inMilliseconds < 200) {
      return null;
    }

    if (_cameraController == null ||
        _isBusy ||
        !_cameraController!.value.isInitialized ||
        _registeredFaceEncodings.isEmpty) {
      return null;
    }

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('Too many consecutive errors, skipping recognition');
      return null;
    }

    _isBusy = true;
    _lastProcessTime = now;

    try {
      final XFile image = await _cameraController!
          .takePicture()
          .timeout(const Duration(seconds: 5));

      final result = await _recognizeFaceInImage(image.path);

      try {
        await File(image.path).delete();
      } catch (e) {
        debugPrint('Warning: Could not delete temp image: $e');
      }

      if (result != null) {
        _consecutiveErrors = 0;

        // Update recognition history for confidence tracking
        _lastRecognitionTime[result] = now;
        _recognitionSuccessCount[result] =
            (_recognitionSuccessCount[result] ?? 0) + 1;

        // Cache this result for quick return next time
        _cachedRecognizedEmployeeId = result;
        _cachedRecognitionTime = now;
      } else {
        _consecutiveErrors++;
      }

      return result;
    } catch (e) {
      _consecutiveErrors++;
      debugPrint('Error in face recognition: $e');

      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        debugPrint('Attempting to recover from recognition errors...');
        _scheduleRecovery();
      }

      return null;
    } finally {
      _isBusy = false;
    }
  }

  void _scheduleRecovery() {
    Timer(const Duration(seconds: 5), () async {
      try {
        if (_cameraController != null) {
          await _testCamera();
          _consecutiveErrors = 0;
          debugPrint('Camera recovery successful');
        }
      } catch (e) {
        debugPrint('Camera recovery failed: $e');
      }
    });
  }

  // Register employee face with improved validation
  Future<bool> registerEmployeeFace(String employeeId, String imagePath) async {
    try {
      debugPrint('Registering face for employee: $employeeId');

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('Image file does not exist: $imagePath');
        return false;
      }

      // Detect faces in the image
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('No face detected in registration image');
        return false;
      }

      Face bestFace = faces.first;
      double maxArea = bestFace.boundingBox.width * bestFace.boundingBox.height;

      for (final face in faces) {
        final area = face.boundingBox.width * face.boundingBox.height;
        if (area > maxArea) {
          maxArea = area;
          bestFace = face;
        }
      }

      if (!_isFaceQualityGood(bestFace)) {
        debugPrint('Face quality not sufficient for registration');
        return false;
      }

      final encoding = _createFaceEncoding(bestFace);

      if (!_isValidEncoding(encoding)) {
        debugPrint('Face encoding quality insufficient');
        return false;
      }

      // Create face images directory
      final directory = await getApplicationDocumentsDirectory();
      final faceImagesDir =
          Directory(path.join(directory.path, 'face_images', employeeId));
      if (!await faceImagesDir.exists()) {
        await faceImagesDir.create(recursive: true);
      }

      // Copy image to dedicated face images directory
      final fileName = 'face_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImagePath = path.join(faceImagesDir.path, fileName);
      await file.copy(newImagePath);

      // Store in registered face encodings map
      if (_registeredFaceEncodings.containsKey(employeeId)) {
        _registeredFaceEncodings[employeeId]!.add(encoding);
        _registeredFaceImages[employeeId]!.add(newImagePath);
      } else {
        _registeredFaceEncodings[employeeId] = [encoding];
        _registeredFaceImages[employeeId] = [newImagePath];
      }

      await _saveFaceData();

      debugPrint('Face registered successfully for employee: $employeeId');
      debugPrint(
          'Total registered employees: ${_registeredFaceEncodings.keys.length}');
      return true;
    } catch (e) {
      debugPrint('Error registering face: $e');
      return false;
    }
  }

  // Register employee face with lower confidence for learning
  Future<bool> registerEmployeeFaceWithLowerConfidence(
      String employeeId, String imagePath) async {
    try {
      debugPrint(
          'Registering face with lower confidence for employee: $employeeId');

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('Image file does not exist: $imagePath');
        return false;
      }

      // Detect faces in the image
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('No face detected in image');
        return false;
      }

      Face bestFace = faces.first;
      double maxArea = bestFace.boundingBox.width * bestFace.boundingBox.height;

      for (final face in faces) {
        final area = face.boundingBox.width * face.boundingBox.height;
        if (area > maxArea) {
          maxArea = area;
          bestFace = face;
        }
      }

      // We're more lenient with quality checks for learning
      if (bestFace.boundingBox.width < 40 || bestFace.boundingBox.height < 40) {
        debugPrint('Face too small for learning');
        return false;
      }

      final encoding = _createFaceEncoding(bestFace);

      // Create face images directory
      final directory = await getApplicationDocumentsDirectory();
      final faceImagesDir =
          Directory(path.join(directory.path, 'face_images', employeeId));
      if (!await faceImagesDir.exists()) {
        await faceImagesDir.create(recursive: true);
      }

      // Copy image to dedicated face images directory
      final fileName =
          'face_learning_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImagePath = path.join(faceImagesDir.path, fileName);
      await file.copy(newImagePath);

      // Store in registered face encodings map
      if (_registeredFaceEncodings.containsKey(employeeId)) {
        _registeredFaceEncodings[employeeId]!.add(encoding);
        _registeredFaceImages[employeeId]!.add(newImagePath);
      } else {
        _registeredFaceEncodings[employeeId] = [encoding];
        _registeredFaceImages[employeeId] = [newImagePath];
      }

      await _saveFaceData();

      debugPrint(
          'Face registered with lower confidence for learning: $employeeId');
      return true;
    } catch (e) {
      debugPrint('Error registering face for learning: $e');
      return false;
    }
  }

  bool _isValidEncoding(List<double> encoding) {
    if (encoding.length < 15) return false;

    for (final value in encoding) {
      if (!value.isFinite) return false;
    }

    final variance = _calculateVariance(encoding);
    return variance > 0.001;
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDifferences = values.fold(0.0, (sum, value) {
      final diff = value - mean;
      return sum + (diff * diff);
    });

    return sumSquaredDifferences / values.length;
  }

  // Validate if employee's face matches for punch in/out with improved matching
  Future<bool> validateEmployeeFaceForAttendance(
      String employeeId, String imagePath) async {
    try {
      if (!_registeredFaceEncodings.containsKey(employeeId)) {
        debugPrint('Employee $employeeId has no registered faces');
        return false;
      }

      // Detect face in the provided image
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        debugPrint('No face detected in attendance image');
        return false;
      }

      // Use the largest face if multiple are detected
      Face bestFace = faces.first;
      double maxArea = bestFace.boundingBox.width * bestFace.boundingBox.height;

      for (final face in faces) {
        final area = face.boundingBox.width * face.boundingBox.height;
        if (area > maxArea) {
          maxArea = area;
          bestFace = face;
        }
      }

      // Check face quality first
      if (!_isFaceQualityGood(bestFace)) {
        debugPrint('Face quality not sufficient for attendance validation');
        return false;
      }

      // Create encoding for the detected face
      final encoding = _createFaceEncoding(bestFace);

      // Check against the registered faces for this employee with a slightly looser threshold
      bool isMatch = _isMatchForEmployee(encoding, employeeId,
          threshold: _verificationThreshold);

      debugPrint(
          'Face validation for $employeeId: ${isMatch ? 'MATCH' : 'NO MATCH'}');
      return isMatch;
    } catch (e) {
      debugPrint('Error validating employee face: $e');
      return false;
    }
  }

  // Special method to check if an encoding matches a specific employee's registered faces
  bool _isMatchForEmployee(List<double> targetEncoding, String employeeId,
      {double threshold = 0.65}) {
    if (!_registeredFaceEncodings.containsKey(employeeId)) return false;

    final storedEncodings = _registeredFaceEncodings[employeeId]!;
    double maxSimilarity = 0.0;

    for (final storedEncoding in storedEncodings) {
      final similarity =
          _calculateWeightedSimilarity(targetEncoding, storedEncoding);
      maxSimilarity = max(maxSimilarity, similarity);
    }

    return maxSimilarity > threshold;
  }

  Future<String?> _recognizeFaceInImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector
          .processImage(inputImage)
          .timeout(const Duration(seconds: 8));

      if (faces.isEmpty) return null;

      Face targetFace = faces.first;
      double maxArea =
          targetFace.boundingBox.width * targetFace.boundingBox.height;

      for (final face in faces) {
        final area = face.boundingBox.width * face.boundingBox.height;
        if (area > maxArea) {
          maxArea = area;
          targetFace = face;
        }
      }

      if (!_isFaceQualityGood(targetFace)) {
        debugPrint('Face quality insufficient for recognition');
        return null;
      }

      final targetEncoding = _createFaceEncoding(targetFace);
      return _findBestMatch(targetEncoding);
    } catch (e) {
      debugPrint('Error recognizing face: $e');
      return null;
    }
  }

  // Optimize face quality checks to be less strict
  bool _isFaceQualityGood(Face face) {
    final bbox = face.boundingBox;

    // Reduce minimum size requirement (from 60 to 50)
    if (bbox.width < 50 || bbox.height < 50) return false;

    // Make aspect ratio check more lenient (from 0.7-1.4 to 0.65-1.5)
    final aspectRatio = bbox.width / bbox.height;
    if (aspectRatio < 0.65 || aspectRatio > 1.5) return false;

    // Reduce edge position check (from 10 to 5)
    if (bbox.left < 5 || bbox.top < 5) return false;

    // More lenient orientation check (from 20 to 25 degrees)
    if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 25)
      return false;
    if (face.headEulerAngleZ != null && face.headEulerAngleZ!.abs() > 25)
      return false;

    // More lenient eye openness check (from 0.5 to 0.4)
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0;
    if (leftEyeOpen < 0.4 && rightEyeOpen < 0.4) return false;

    return true;
  }

  List<double> _createFaceEncoding(Face face) {
    List<double> encoding = [];

    try {
      final bbox = face.boundingBox;
      // Add normalized bounding box dimensions
      encoding.addAll([
        bbox.width / 500.0,
        bbox.height / 500.0,
        bbox.width / bbox.height,
      ]);

      // Add facial landmarks (normalized to face bounding box)
      final landmarks = face.landmarks;
      final keyLandmarks = [
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.noseBase,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.rightMouth,
        FaceLandmarkType.bottomMouth,
        FaceLandmarkType.leftCheek,
        FaceLandmarkType.rightCheek,
      ];

      for (final landmarkType in keyLandmarks) {
        if (landmarks[landmarkType] != null) {
          final point = landmarks[landmarkType]!.position;
          final normalizedX =
              ((point.x - bbox.left) / bbox.width).clamp(0.0, 1.0);
          final normalizedY =
              ((point.y - bbox.top) / bbox.height).clamp(0.0, 1.0);
          encoding.addAll([normalizedX, normalizedY]);
        } else {
          encoding.addAll([0.5, 0.5]); // Default placeholder values
        }
      }

      // Add head orientation
      encoding.add(face.headEulerAngleX != null
          ? (face.headEulerAngleX! / 90.0).clamp(-1.0, 1.0)
          : 0.0);
      encoding.add(face.headEulerAngleY != null
          ? (face.headEulerAngleY! / 90.0).clamp(-1.0, 1.0)
          : 0.0);
      encoding.add(face.headEulerAngleZ != null
          ? (face.headEulerAngleZ! / 90.0).clamp(-1.0, 1.0)
          : 0.0);

      // Add facial classification probabilities
      encoding.add(face.smilingProbability ?? 0.5);
      encoding.add(face.leftEyeOpenProbability ?? 1.0);
      encoding.add(face.rightEyeOpenProbability ?? 1.0);

      // Add inter-landmark distances (additional features)
      if (landmarks[FaceLandmarkType.leftEye] != null &&
          landmarks[FaceLandmarkType.rightEye] != null) {
        final leftEye = landmarks[FaceLandmarkType.leftEye]!.position;
        final rightEye = landmarks[FaceLandmarkType.rightEye]!.position;
        final eyeDistance = sqrt(
            pow(leftEye.x - rightEye.x, 2) + pow(leftEye.y - rightEye.y, 2));
        encoding.add(eyeDistance / bbox.width);
      } else {
        encoding.add(0.3);
      }

      return encoding;
    } catch (e) {
      debugPrint('Error creating face encoding: $e');

      return List.filled(25, 0.0);
    }
  }

  String? _findBestMatch(List<double> targetEncoding) {
    if (_registeredFaceEncodings.isEmpty) return null;

    String? bestMatch;
    double bestSimilarity = 0.0;

    // Use the class constant for the base threshold
    final baseThreshold =
        _baseSimilarityThreshold; // Using 0.55 instead of 0.60

    final now = DateTime.now();

    // Add a fallback match for when similarity is close but not quite there
    String? fallbackMatch = null;
    double fallbackSimilarity = 0.0;
    final fallbackThreshold = baseThreshold - 0.10; // Very lenient fallback

    // Check each registered employee
    for (final entry in _registeredFaceEncodings.entries) {
      final employeeId = entry.key;
      final storedEncodings = entry.value;

      // Calculate best similarity score for this employee
      double maxSimilarity = 0.0;
      for (final storedEncoding in storedEncodings) {
        final similarity =
            _calculateWeightedSimilarity(targetEncoding, storedEncoding);
        maxSimilarity = max(maxSimilarity, similarity);
      }

      final lastRecognitionTime = _lastRecognitionTime[employeeId];
      double employeeThreshold = baseThreshold;

      // More aggressive threshold reduction for recently seen employees
      if (lastRecognitionTime != null) {
        final secondsSinceLastRecognition =
            now.difference(lastRecognitionTime).inSeconds;

        if (secondsSinceLastRecognition < 15) {
          // More aggressive reduction (from 0.05 to 0.07)
          employeeThreshold = baseThreshold - 0.07;
        } else if (secondsSinceLastRecognition < 60) {
          // More aggressive reduction (from 0.02 to 0.05)
          employeeThreshold = baseThreshold - 0.05;
        }
      }

      // Main matching logic
      if (maxSimilarity > employeeThreshold && maxSimilarity > bestSimilarity) {
        bestSimilarity = maxSimilarity;
        bestMatch = employeeId;
      }
      // Fallback matching logic
      else if (maxSimilarity > fallbackThreshold &&
          maxSimilarity > fallbackSimilarity) {
        fallbackSimilarity = maxSimilarity;
        fallbackMatch = employeeId;
      }
    }

    // If we found a match, use it
    if (bestMatch != null) {
      debugPrint(
          'Best match: $bestMatch with similarity: ${bestSimilarity.toStringAsFixed(3)}');
      return bestMatch;
    }
    // If no match but we have a fallback, use that if we've seen this employee recently
    else if (fallbackMatch != null) {
      final lastRecognitionTime = _lastRecognitionTime[fallbackMatch];
      if (lastRecognitionTime != null &&
          now.difference(lastRecognitionTime).inSeconds < 30) {
        debugPrint(
            'Using fallback match: $fallbackMatch with lower similarity: ${fallbackSimilarity.toStringAsFixed(3)}');
        return fallbackMatch;
      }
    }

    return null;
  }

  double _calculateWeightedSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      final maxLen = max(a.length, b.length);
      final paddedA = List<double>.from(a)
        ..addAll(List.filled(maxLen - a.length, 0.0));
      final paddedB = List<double>.from(b)
        ..addAll(List.filled(maxLen - b.length, 0.0));
      return _calculateWeightedSimilarity(paddedA, paddedB);
    }

    try {
      final weights = <double>[
        1.0, 1.0, 2.0, // Bounding box dimensions and ratio
        3.0, 3.0, // Left eye position
        3.0, 3.0, // Right eye position
        2.5, 2.5, // Nose position
        2.0, 2.0, // Left mouth position
        2.0, 2.0, // Right mouth position
        2.0, 2.0, // Bottom mouth position
        1.0, 1.0, // Cheek positions
        1.5, 1.5, 1.5, // Head orientation
        1.0, 1.5, 1.5, // Facial expressions
        3.0, // Inter-eye distance
      ];

      // Ensure we have enough weights for all features
      while (weights.length < a.length) {
        weights.add(1.0);
      }

      // Calculate weighted cosine similarity
      double weightedDotProduct = 0.0;
      double weightedNormA = 0.0;
      double weightedNormB = 0.0;

      for (int i = 0; i < a.length && i < weights.length; i++) {
        final weight = weights[i];
        weightedDotProduct += weight * a[i] * b[i];
        weightedNormA += weight * a[i] * a[i];
        weightedNormB += weight * b[i] * b[i];
      }

      if (weightedNormA <= 0.0 || weightedNormB <= 0.0) return 0.0;

      final similarity =
          weightedDotProduct / (sqrt(weightedNormA) * sqrt(weightedNormB));
      return similarity.clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating similarity: $e');
      return 0.0;
    }
  }

  // Load registered face data
  Future<void> loadStoredFaceRegistrations() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clear existing data first
      _registeredFaceEncodings.clear();
      _registeredFaceImages.clear();

      final encodingsData = prefs.getString('registered_face_encodings');
      if (encodingsData != null) {
        final Map<String, dynamic> data = jsonDecode(encodingsData);
        for (final entry in data.entries) {
          try {
            final List<dynamic> encodingsList = entry.value;
            _registeredFaceEncodings[entry.key] = encodingsList
                .map((encoding) => List<double>.from(encoding))
                .toList();
          } catch (e) {
            debugPrint('Error loading encoding for ${entry.key}: $e');
          }
        }
      }

      final imagesData = prefs.getString('registered_face_images');
      if (imagesData != null) {
        final Map<String, dynamic> data = jsonDecode(imagesData);
        for (final entry in data.entries) {
          try {
            _registeredFaceImages[entry.key] = List<String>.from(entry.value);
          } catch (e) {
            debugPrint('Error loading images for ${entry.key}: $e');
          }
        }
      }

      // Verify image files still exist
      for (final employeeId in _registeredFaceImages.keys.toList()) {
        final images = _registeredFaceImages[employeeId]!;
        final validImages = <String>[];

        for (final imagePath in images) {
          if (await File(imagePath).exists()) {
            validImages.add(imagePath);
          } else {
            debugPrint('Warning: Registered face image not found: $imagePath');
          }
        }

        if (validImages.isEmpty) {
          // If no valid images remain, remove the employee registration entirely
          _registeredFaceEncodings.remove(employeeId);
          _registeredFaceImages.remove(employeeId);
        } else {
          _registeredFaceImages[employeeId] = validImages;
        }
      }

      debugPrint(
          'Loaded registered face data for ${_registeredFaceEncodings.keys.length} employees');
    } catch (e) {
      debugPrint('Error loading stored face registrations: $e');
    }
  }

  // Save registered face data
  Future<void> _saveFaceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final Map<String, dynamic> encodingsData = {};
      for (final entry in _registeredFaceEncodings.entries) {
        encodingsData[entry.key] =
            entry.value.map((encoding) => encoding).toList();
      }
      await prefs.setString(
          'registered_face_encodings', jsonEncode(encodingsData));

      final Map<String, dynamic> imagesData = {};
      for (final entry in _registeredFaceImages.entries) {
        imagesData[entry.key] = entry.value;
      }
      await prefs.setString('registered_face_images', jsonEncode(imagesData));

      debugPrint('Registered face data saved successfully');
    } catch (e) {
      debugPrint('Error saving face data: $e');
    }
  }

  Future<List<String>> getEmployeeFaceImages(String employeeId) async {
    return _registeredFaceImages[employeeId] ?? [];
  }

  Future<void> deleteEmployeeFaceImage(
      String employeeId, String imagePath) async {
    try {
      if (!_registeredFaceImages.containsKey(employeeId)) return;

      final imageIndex = _registeredFaceImages[employeeId]!.indexOf(imagePath);
      if (imageIndex < 0) return;

      // Remove image from registered images list
      _registeredFaceImages[employeeId]!.removeAt(imageIndex);

      // Also remove corresponding encoding if indexes match
      if (_registeredFaceEncodings.containsKey(employeeId) &&
          imageIndex < _registeredFaceEncodings[employeeId]!.length) {
        _registeredFaceEncodings[employeeId]!.removeAt(imageIndex);
      }

      // If no images remain, remove the employee entirely
      if (_registeredFaceImages[employeeId]?.isEmpty == true) {
        _registeredFaceImages.remove(employeeId);
        _registeredFaceEncodings.remove(employeeId);
      }

      // Delete the file
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _saveFaceData();
      debugPrint('Face image deleted for employee: $employeeId');
    } catch (e) {
      debugPrint('Error deleting face image: $e');
    }
  }

  Future<void> clearEmployeeFaceData(String employeeId) async {
    try {
      final faceImages = _registeredFaceImages[employeeId] ?? [];
      for (final imagePath in faceImages) {
        final file = File(imagePath);
        if (await file.exists() && imagePath.contains('face_images')) {
          await file.delete();
        }
      }

      _registeredFaceEncodings.remove(employeeId);
      _registeredFaceImages.remove(employeeId);
      _lastRecognitionTime.remove(employeeId);
      _recognitionSuccessCount.remove(employeeId);

      await _saveFaceData();

      debugPrint('Cleared all registered face data for employee: $employeeId');
    } catch (e) {
      debugPrint('Error clearing face data: $e');
    }
  }

  // Return detailed recognition statistics
  Map<String, dynamic> getRecognitionStats() {
    return {
      'totalEmployees': _registeredFaceEncodings.keys.length,
      'totalFaceImages': _registeredFaceImages.values
          .fold<int>(0, (sum, images) => sum + images.length),
      'avgImagesPerEmployee': _registeredFaceEncodings.isNotEmpty
          ? _registeredFaceImages.values
                  .fold<int>(0, (sum, images) => sum + images.length) /
              _registeredFaceImages.length
          : 0.0,
      'consecutiveErrors': _consecutiveErrors,
      'isHealthy': _consecutiveErrors < _maxConsecutiveErrors,
      'mostRecognizedEmployee': _getMostRecognizedEmployee(),
    };
  }

  String? _getMostRecognizedEmployee() {
    if (_recognitionSuccessCount.isEmpty) return null;

    String? mostRecognized;
    int maxCount = 0;

    for (final entry in _recognitionSuccessCount.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostRecognized = entry.key;
      }
    }

    return mostRecognized;
  }

  bool isHealthy() {
    return _consecutiveErrors < _maxConsecutiveErrors &&
        _isInitialized &&
        (_cameraController?.value.isInitialized ?? false);
  }

  void resetErrorCounters() {
    _consecutiveErrors = 0;
  }

  void dispose() {
    _disposeController();
    _faceDetector.close();
    _isInitialized = false;
  }
}

final faceRecognitionServiceProvider = Provider<FaceRecognitionService>((ref) {
  final service = FaceRecognitionService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
