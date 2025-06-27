import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/face_recognition/face_recognition_service.dart';

class FaceRecognitionWidget extends ConsumerStatefulWidget {
  final Function(String?) onEmployeeDetected;
  final bool isActive;

  const FaceRecognitionWidget({
    Key? key,
    required this.onEmployeeDetected,
    this.isActive = true,
  }) : super(key: key);

  @override
  ConsumerState<FaceRecognitionWidget> createState() =>
      _FaceRecognitionWidgetState();
}

class _FaceRecognitionWidgetState extends ConsumerState<FaceRecognitionWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isCameraInitialized = false;
  Timer? _recognitionTimer;
  Timer? _watchdogTimer; // Monitor to detect stuck states
  bool _isProcessing = false;
  int _consecutiveFailures = 0;
  String _currentStatus = 'idle';
  DateTime? _lastSuccessfulRecognition;
  String? _lastDetectedEmployeeId;
  int _confidenceCounter = 0;
  int _noChangeCounter = 0; // Track frames with no state change
  DateTime? _lastProcessingStartTime;

  // Track if widget is mounted to prevent async operations after disposal
  bool _isMounted = true;

  late AnimationController _pulseController;
  late AnimationController _scanController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _initializeCamera();

    // Start watchdog timer to detect frozen states
    _startWatchdogTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recognitionTimer?.cancel();
    _watchdogTimer?.cancel();
    _pulseController.dispose();
    _scanController.dispose();
    _isMounted = false;
    super.dispose();
  }

  // Watchdog timer to detect and recover from stuck states
  void _startWatchdogTimer() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isMounted) {
        timer.cancel();
        return;
      }

      // If we've been processing for more than 5 seconds, something is wrong
      if (_isProcessing && _lastProcessingStartTime != null) {
        final processingDuration =
            DateTime.now().difference(_lastProcessingStartTime!);
        if (processingDuration.inSeconds > 5) {
          debugPrint(
              'Face recognition appears stuck in processing state for ${processingDuration.inSeconds}s');
          _recoverFromStuckState();
        }
      }

      // If we've had no state change for 30 seconds, try to restart
      if (_noChangeCounter > 3) {
        debugPrint('Face recognition appears frozen - restarting camera');
        _recoverFromStuckState();
      } else {
        _noChangeCounter++;
      }
    });
  }

  // Method to recover from stuck states
  void _recoverFromStuckState() {
    if (!_isMounted) return;

    debugPrint('🔄 Recovering face recognition from stuck state');

    setState(() {
      _isProcessing = false;
      _lastProcessingStartTime = null;
      _noChangeCounter = 0;
    });

    // Force camera reinitialization
    _reinitializeCamera();
  }

  // Complete camera reinitialization
  Future<void> _reinitializeCamera() async {
    if (!_isMounted) return;

    final faceService = ref.read(faceRecognitionServiceProvider);

    setState(() {
      _isCameraInitialized = false;
      _currentStatus = 'initializing';
    });

    // Force camera disposal
    await faceService.forceDispose();

    // Short delay to ensure resources are released
    await Future.delayed(const Duration(milliseconds: 500));

    if (!_isMounted) return;

    // Reinitialize
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseRecognition();
      // When app goes to background, release camera resources completely
      final faceService = ref.read(faceRecognitionServiceProvider);
      faceService.forceDispose();
    } else if (state == AppLifecycleState.resumed) {
      // On resume, reinitialize the camera completely
      _reinitializeCamera();
    }
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(FaceRecognitionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _resumeRecognition();
      } else {
        _pauseRecognition();
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!_isMounted) return;

    try {
      setState(() {
        _currentStatus = 'initializing';
      });

      final faceService = ref.read(faceRecognitionServiceProvider);
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (_isMounted) {
          setState(() {
            _currentStatus = 'error';
          });
        }
        return;
      }

      await faceService.initialize(cameras);

      if (_isMounted) {
        setState(() {
          _isCameraInitialized = true;
          _currentStatus = widget.isActive ? 'active' : 'paused';
          _noChangeCounter = 0; // Reset no change counter on successful init
        });

        if (widget.isActive) {
          _startFaceRecognition();
        }
      }
    } catch (e) {
      if (_isMounted) {
        setState(() {
          _currentStatus = 'error';
        });
      }
      debugPrint('Error initializing camera: $e');

      // Try to recover after a delay
      Future.delayed(const Duration(seconds: 3), () {
        if (_isMounted) {
          _initializeCamera();
        }
      });
    }
  }

  String _getStatusMessage() {
    final faceService = ref.read(faceRecognitionServiceProvider);
    final employeeCount = faceService.getActualRegisteredEmployeeCount();

    switch (_currentStatus) {
      case 'initializing':
        return 'Starting...';
      case 'error':
        return 'Camera error';
      case 'paused':
        return 'Paused';
      case 'no_faces':
        return 'No faces\nregistered';
      case 'processing':
        return 'Scanning...';
      case 'active':
        if (employeeCount == 0) {
          return 'No faces\nregistered';
        }
        return 'Looking for\nfaces...';
      case 'detected':
        return 'Employee\ndetected!';
      default:
        return 'Ready';
    }
  }

  void _startFaceRecognition() {
    if (!_isCameraInitialized || !_isMounted) return;

    final faceService = ref.read(faceRecognitionServiceProvider);
    final actualEmployeeCount = faceService.getActualRegisteredEmployeeCount();

    if (actualEmployeeCount == 0) {
      setState(() {
        _currentStatus = 'no_faces';
      });
      return;
    }

    _recognitionTimer?.cancel();
    _consecutiveFailures = 0;
    _confidenceCounter = 0;
    _lastDetectedEmployeeId = null;
    _noChangeCounter = 0; // Reset no change counter

    setState(() {
      _currentStatus = 'active';
    });

    _pulseController.repeat(reverse: true);
    _scheduleNextRecognition(1000);
  }

  void _scheduleNextRecognition(int intervalMs) {
    _recognitionTimer?.cancel();

    _recognitionTimer = Timer(Duration(milliseconds: intervalMs), () async {
      if (!widget.isActive || !_isMounted || !_isCameraInitialized) return;

      await _performRecognition();
    });
  }

  Future<void> _performRecognition() async {
    if (_isProcessing || !_isMounted) {
      _scheduleNextRecognition(500);
      return;
    }

    final faceService = ref.read(faceRecognitionServiceProvider);
    if (faceService.isBusy) {
      _scheduleNextRecognition(500);
      return;
    }

    if (!_isMounted) return;

    setState(() {
      _isProcessing = true;
      _currentStatus = 'processing';
      _lastProcessingStartTime = DateTime.now();
    });

    _noChangeCounter = 0; // Reset no change counter
    _scanController.forward().then((_) => _scanController.reverse());

    try {
      final employeeId = await faceService.processImageForRecognition();

      if (!_isMounted) return;

      if (employeeId != null) {
        // Check if this is the same employee consistently detected
        if (employeeId == _lastDetectedEmployeeId) {
          _confidenceCounter++;
        } else {
          // Reset counter for new employee
          _confidenceCounter = 1;
          _lastDetectedEmployeeId = employeeId;
        }

        // Only trigger detection after consistent detections
        if (_confidenceCounter >= 3) {
          _lastSuccessfulRecognition = DateTime.now();
          _consecutiveFailures = 0;

          setState(() {
            _currentStatus = 'detected';
            _isProcessing = false;
            _lastProcessingStartTime = null;
          });

          widget.onEmployeeDetected(employeeId);
          _pulseController.stop();

          // Pause for a moment after successful detection
          _scheduleNextRecognition(3000);
        } else {
          // Continue scanning to build confidence
          setState(() {
            _currentStatus = 'active';
            _isProcessing = false;
            _lastProcessingStartTime = null;
          });
          _scheduleNextRecognition(500); // Scan quickly to build confidence
        }
      } else {
        // No face detected - continue scanning
        _consecutiveFailures++;

        if (!_isMounted) return;

        setState(() {
          _currentStatus = 'active';
          _isProcessing = false;
          _lastProcessingStartTime = null;
        });

        // Continue with normal interval
        _scheduleNextRecognition(1000);
      }
    } catch (e) {
      debugPrint('Error during face recognition: $e');
      _consecutiveFailures++;

      if (!_isMounted) return;

      setState(() {
        _currentStatus = _consecutiveFailures > 3 ? 'error' : 'active';
        _isProcessing = false;
        _lastProcessingStartTime = null;
      });

      if (_consecutiveFailures > 5) {
        // Try to recover by reinitializing the camera
        _reinitializeCamera();
      } else {
        _scheduleNextRecognition(2000);
      }
    }
  }

  void _pauseRecognition() {
    _recognitionTimer?.cancel();
    _pulseController.stop();
    _scanController.stop();

    if (_isMounted) {
      setState(() {
        _currentStatus = 'paused';
        _isProcessing = false;
        _lastProcessingStartTime = null;
      });
    }
  }

  void _resumeRecognition() {
    if (_isCameraInitialized && widget.isActive && _isMounted) {
      _startFaceRecognition();
    }
  }

  Future<void> _retryInitialization() async {
    if (!_isMounted) return;

    setState(() {
      _isCameraInitialized = false;
      _consecutiveFailures = 0;
      _confidenceCounter = 0;
      _lastDetectedEmployeeId = null;
      _noChangeCounter = 0;
    });
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    final faceService = ref.watch(faceRecognitionServiceProvider);
    final actualEmployeeCount = faceService.getActualRegisteredEmployeeCount();
    final bool hasError = _currentStatus == 'error';

    return GestureDetector(
      onTap: () {
        if (_currentStatus == 'no_faces' || actualEmployeeCount == 0) {
          // Navigate to face registration
          Navigator.pushNamed(context, '/attendance/face-registration');
        } else if (hasError) {
          _retryInitialization();
        }
      },
      child: Container(
        height: 140,
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildContent(faceService),
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (_currentStatus) {
      case 'error':
        return Colors.red;
      case 'detected':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'no_faces':
        return Colors.orange;
      case 'paused':
        return Colors.grey;
      default:
        return widget.isActive ? Colors.green : Colors.grey;
    }
  }

  Widget _buildContent(FaceRecognitionService faceService) {
    if (_currentStatus == 'error') {
      return _buildErrorWidget();
    }

    final cameraController = faceService.cameraController;
    final isServiceInitialized = _isCameraInitialized &&
        cameraController != null &&
        cameraController.value.isInitialized;

    if (!isServiceInitialized) {
      return _buildLoadingWidget();
    }

    final actualEmployeeCount = faceService.getActualRegisteredEmployeeCount();
    if (actualEmployeeCount == 0) {
      return _buildNoFacesWidget();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        CameraPreview(cameraController),

        // Scanning animation
        if (_currentStatus == 'processing')
          AnimatedBuilder(
            animation: _scanAnimation,
            builder: (context, child) {
              return Positioned(
                top: _scanAnimation.value * 140,
                left: 15,
                right: 15,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.blue,
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        // Face detection circle
        if (_currentStatus == 'active' || _currentStatus == 'detected')
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 90 *
                      (_currentStatus == 'detected'
                          ? 1.0
                          : _pulseAnimation.value),
                  height: 90 *
                      (_currentStatus == 'detected'
                          ? 1.0
                          : _pulseAnimation.value),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _currentStatus == 'detected'
                          ? Colors.green.withOpacity(0.9)
                          : Colors.white.withOpacity(0.8),
                      width: _currentStatus == 'detected' ? 3 : 2,
                    ),
                    borderRadius: BorderRadius.circular(45),
                  ),
                ),
              );
            },
          ),

        // Status message overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Text(
              _getStatusMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),

        // Status indicator
        Positioned(
          top: 6,
          right: 6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getBorderColor(),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Employee count badge
        Positioned(
          top: 6,
          left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$actualEmployeeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Processing indicator
        if (_isProcessing)
          Positioned(
            top: 6,
            right: 24,
            child: SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),

        // Confidence indicator for consistent detection
        if (_lastDetectedEmployeeId != null &&
            _confidenceCounter > 0 &&
            _confidenceCounter < 3)
          Positioned(
            bottom: 30,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  return Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _confidenceCounter
                          ? Colors.green
                          : Colors.grey.withOpacity(0.5),
                    ),
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      color: Colors.grey[100],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 8),
          Text(
            'Starting...',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.red[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 24),
          const SizedBox(height: 6),
          const Text(
            'Camera\nError',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 10),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _retryInitialization,
            child: const Text('Retry', style: TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoFacesWidget() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[100]!, Colors.orange[50]!],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_outlined, color: Colors.orange[600], size: 30),
          const SizedBox(height: 6),
          Text(
            'No Faces\nRegistered',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.orange[800],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to register',
            style: TextStyle(color: Colors.orange[600], fontSize: 8),
          ),
        ],
      ),
    );
  }
}
