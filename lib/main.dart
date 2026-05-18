import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

const Color kBlue = Color(0xFF1565C0);
const Color kLightBlue = Color(0xFF1E88E5);

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NSL Recog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.pan_tool_alt,
                size: 100,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'NSL Recog',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Nigerian Sign Language Recognition',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'NSL Recog',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Colors.white],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: kBlue,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: kBlue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pan_tool_alt,
                  size: 100,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Nigerian Sign Language\nRecognition System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Point your camera at a hand gesture\nto recognise NSL alphabets',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 50),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraScreen()),
                  );
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Start Recognition'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Interpreter? _interpreter;
  List<String> _labels = [];
  String _result = 'Initialising...';
  double _confidence = 0.0;
  bool _isProcessing = false;
  bool _isModelLoaded = false;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initCamera(_currentCameraIndex);
    _loadModel();
  }

  Future<void> _loadModel() async {
  try {
    // Load model from assets as bytes first
    final modelData = await rootBundle.load('assets/nsl_model.tflite');
    final modelBytes = modelData.buffer.asUint8List();
    
    // Create interpreter from bytes
    _interpreter = Interpreter.fromBuffer(modelBytes);
    
    // Load labels
    final labelsData = await rootBundle.loadString('assets/labels.txt');
    _labels = labelsData.trim().split('\n');
    
    setState(() {
      _isModelLoaded = true;
      _result = 'Ready! Show a hand gesture';
    });
  } catch (e) {
    setState(() => _result = 'Error loading model: $e');
  }
}
  Future<void> _initCamera(int cameraIndex) async {
    if (cameras.isEmpty) return;
    if (_controller != null) {
      await _controller!.stopImageStream();
      await _controller!.dispose();
    }
    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _controller!.startImageStream(_processFrame);
    }
  }

  Future<void> _switchCamera() async {
    if (cameras.length < 2) return;
    _currentCameraIndex = _currentCameraIndex == 0 ? 1 : 0;
    await _initCamera(_currentCameraIndex);
  }

  void _processFrame(CameraImage cameraImage) async {
    if (_isProcessing || !_isModelLoaded) return;
    _isProcessing = true;
    try {
      final result = await _runInference(cameraImage);
      if (mounted) {
        setState(() {
          _result = result['label'];
          _confidence = result['confidence'];
        });
      }
    } catch (e) {
      // Continue processing
    }
    _isProcessing = false;
  }

  Future<Map<String, dynamic>> _runInference(CameraImage cameraImage) async {
    final image = _convertCameraImage(cameraImage);
    final resized = img.copyResize(image, width: 224, height: 224);

    final inputType = _interpreter!.getInputTensor(0).type;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputLength = outputShape.isNotEmpty ? outputShape.last : _labels.length;

    final input = List.generate(
      1,
      (_) => List.generate(
        224,
        (y) => List.generate(224, (x) {
          final pixel = resized.getPixel(x, y);
          if (inputType == TfLiteType.uint8) {
            return [pixel.r, pixel.g, pixel.b];
          }
          return [
            pixel.r / 255.0,
            pixel.g / 255.0,
            pixel.b / 255.0,
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(outputLength, 0.0));
    _interpreter!.run(input, output);

    final probabilities = output[0];
    int maxIndex = 0;
    double maxProb = 0.0;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }

    return {
      'label': maxIndex < _labels.length ? _labels[maxIndex] : 'Unknown',
      'confidence': maxProb,
    };
  }

  img.Image _convertCameraImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 2;

    final imageBytes = Uint8List(width * height * 3);
    int byteIndex = 0;

    for (int y = 0; y < height; y++) {
      final int uvRow = uvRowStride * (y >> 1);
      for (int x = 0; x < width; x++) {
        final int uvCol = (x >> 1) * uvPixelStride;
        final int yIndex = y * cameraImage.planes[0].bytesPerRow + x;

        final int yValue = cameraImage.planes[0].bytes[yIndex] & 0xff;
        final int uValue = cameraImage.planes[1].bytes[uvRow + uvCol] & 0xff;
        final int vValue = cameraImage.planes[2].bytes[uvRow + uvCol] & 0xff;

        final int r = (yValue + 1.403 * (vValue - 128)).round().clamp(0, 255);
        final int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round().clamp(0, 255);
        final int b = (yValue + 1.770 * (uValue - 128)).round().clamp(0, 255);

        imageBytes[byteIndex++] = r;
        imageBytes[byteIndex++] = g;
        imageBytes[byteIndex++] = b;
      }
    }

    return img.Image.fromBytes(width, height, imageBytes, format: img.Format.rgb);
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'NSL Camera',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _controller != null && _controller!.value.isInitialized
                ? CameraPreview(_controller!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
          ),
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _result,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(_confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}