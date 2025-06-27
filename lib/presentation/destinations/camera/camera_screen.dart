import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/camera/camera_service.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final String title;

  const CameraScreen({
    super.key,
    required this.title,
  });

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  bool _isInitializing = true;
  String? _errorMessage;
  bool _isTakingPicture = false;
  int _countdownValue = 0;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraService = ref.read(cameraServiceProvider);

    // Handle app lifecycle changes
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // App is inactive, release camera resources
      if (cameraService.isInitialized) {
        cameraService.disposeCamera();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App is resumed, reinitialize camera if needed
      if (!cameraService.isInitialized) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    final cameraService = ref.read(cameraServiceProvider);

    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      // Release camera resources first
      await cameraService.disposeCamera();

      // Short delay to ensure resources are freed
      await Future.delayed(const Duration(milliseconds: 300));

      // Initialize camera
      await cameraService.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Could not initialize camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Ensure camera is disposed when screen is closed
    final cameraService = ref.read(cameraServiceProvider);
    cameraService.disposeCamera();

    super.dispose();
  }

  void _startCountdown() {
    if (_isTakingPicture) return;

    setState(() {
      _isTakingPicture = true;
      _countdownValue = 3;
    });

    // Start countdown timer
    _tickCountdown();
  }

  void _tickCountdown() {
    if (_countdownValue <= 0) {
      _takePicture();
      return;
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _countdownValue--;
        });
        _tickCountdown();
      }
    });
  }

  Future<void> _takePicture() async {
    final cameraService = ref.read(cameraServiceProvider);

    // Cancel any existing timeout timer
    _timeoutTimer?.cancel();

    // Create a flag to track if picture was completed
    bool pictureCompleted = false;

    // Set up a timeout to prevent getting stuck
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (!pictureCompleted && mounted) {
        debugPrint('Picture capture timed out - forcing completion');

        // Force reset UI state
        setState(() {
          _isTakingPicture = false;
          _errorMessage = 'Photo capture timed out. Please try again.';
        });

        // Try to recover camera service
        cameraService.disposeCamera().then((_) {
          if (mounted) {
            _initializeCamera();
          }
        });
      }
    });

    try {
      // Take the picture with a short timeout to prevent hanging
      final String? imagePath = await cameraService
          .takePicture()
          .timeout(const Duration(seconds: 4), onTimeout: () {
        debugPrint('takePicture() timed out');
        return null;
      });

      // Mark as completed to prevent timeout from triggering
      pictureCompleted = true;
      _timeoutTimer?.cancel();

      if (imagePath != null && mounted) {
        // Make sure camera is released before navigating back
        await cameraService.disposeCamera();
        Navigator.pop(context, imagePath);
      } else {
        if (mounted) {
          setState(() {
            _isTakingPicture = false;
            _errorMessage = 'Failed to capture image. Please try again.';
          });
        }
      }
    } catch (e) {
      // Mark as completed to prevent timeout from triggering
      pictureCompleted = true;
      _timeoutTimer?.cancel();

      debugPrint('Error taking picture: $e');
      if (mounted) {
        setState(() {
          _isTakingPicture = false;
          _errorMessage = 'Error taking picture: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraService = ref.watch(cameraServiceProvider);

    return WillPopScope(
      // Ensure camera is disposed when navigating back
      onWillPop: () async {
        await cameraService.disposeCamera();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // Ensure camera is disposed before navigating back
              await cameraService.disposeCamera();
              if (mounted) Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: Colors.black,
        body: _buildBody(cameraService),
      ),
    );
  }

  Widget _buildBody(CameraService cameraService) {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitializing = true;
                  });
                  _initializeCamera();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (cameraService.controller == null ||
        !cameraService.controller!.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Camera preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CameraPreview(cameraService.controller!),
                ),
              ),

              // Face position guide
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withOpacity(0.7), width: 2),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),

              // Instructions overlay
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Position your face within the circle and look directly at the camera',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Countdown overlay
              if (_isTakingPicture && _countdownValue > 0)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Text(
                      _countdownValue.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // "Taking photo" indicator
              if (_isTakingPicture && _countdownValue <= 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Taking photo...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Bottom controls
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isTakingPicture
                      ? null
                      : () async {
                          // Ensure camera is disposed before navigating back
                          await cameraService.disposeCamera();
                          if (mounted) Navigator.pop(context);
                        },
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              // Take photo button
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  onPressed: _isTakingPicture ? null : _startCountdown,
                  child: const Text('Take Photo'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
