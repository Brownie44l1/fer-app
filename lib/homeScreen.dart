import 'dart:io';
import 'package:camera/camera.dart';
import 'package:emotion_recognition_app/result_screen.dart';
import 'package:emotion_recognition_app/service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitCamera();
  }

  Future<void> _checkPermissionsAndInitCamera() async {
    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          _showErrorDialog('Camera permission denied');
          return;
        }
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _showErrorDialog('No cameras available');
        return;
      }

      int initialIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front);
      if (initialIndex == -1) initialIndex = 0;

      _selectedCameraIndex = initialIndex;

      await _initCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      _showErrorDialog('Error initializing camera: $e');
    }
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    final prevController = _cameraController;

    if (prevController != null) {
      await prevController.dispose();
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _cameraController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _toggleCamera() {
    if (_cameras.length < 2) {
      _showErrorDialog('Only one camera available.');
      return;
    }

    setState(() {
      final lensDirection = _cameraController?.description.lensDirection;
      CameraLensDirection newDirection;

      if (lensDirection == CameraLensDirection.front) {
        newDirection = CameraLensDirection.back;
      } else {
        newDirection = CameraLensDirection.front;
      }

      final newIndex =
          _cameras.indexWhere((c) => c.lensDirection == newDirection);

      if (newIndex != -1) {
        _selectedCameraIndex = newIndex;
        _initCamera(_cameras[_selectedCameraIndex]);
      } else {
        _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
        _initCamera(_cameras[_selectedCameraIndex]);
      }
    });
  }

  Future<void> _captureAndDetect() async {
    if (_isProcessing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      print('Capture aborted.');
      return;
    }

    setState(() => _isProcessing = true);
    _showLoadingDialog();

    try {
      await _initializeControllerFuture;
      await _cameraController!.setFlashMode(FlashMode.off);

      final image = await _cameraController!.takePicture();

      dynamic input;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        input = bytes;
      } else {
        input = File(image.path);
      }

      final result = await EmotionService().detectEmotions(input);

      Navigator.pop(context); // close loading

      if (result.isEmpty || result['emotion'] == null) {
        _showErrorDialog('No emotion detected.');
      } else {
        // Navigate to result screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmotionResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _uploadAndDetect() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isProcessing = true);
    _showLoadingDialog();

    try {
      dynamic input;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        input = bytes;
      } else {
        input = File(picked.path);
      }

      final result = await EmotionService().detectEmotions(input);

      Navigator.pop(context);

      if (result.isEmpty || result['emotion'] == null) {
        _showErrorDialog('No emotion detected.');
      } else {
        // Navigate to result screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EmotionResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                "Analyzing emotion...",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Error"),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EmotiSense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2563EB), // blue-600
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: _toggleCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _cameraController == null
                ? const Center(child: Text('Initializing camera...'))
                : FutureBuilder(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return Center(
                          child: Stack(
                            children: [
                              CameraPreview(_cameraController!),
                              CustomPaint(
                                painter: FaceGuidePainter(),
                                child: Container(
                                  color: Colors.transparent,
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: const Center(
                                    child: Text(
                                      "Align your face within the box",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  label: const Text(
                    'Capture & Detect',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB), // blue-600
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _captureAndDetect,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library, color: Colors.white),
                  label: const Text(
                    'Upload Picture',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2), // cyan-600
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _uploadAndDetect,
                ),
                const SizedBox(height: 25),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final rectWidth = size.width * 0.7;
    final rectHeight = size.height * 0.5;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: rectWidth,
      height: rectHeight,
    );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}