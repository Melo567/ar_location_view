import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ArCamera extends StatefulWidget {
  const ArCamera({
    super.key,
    required this.onCameraError,
    required this.onCameraSuccess,
    this.onPreviewAspectRatio,
  });

  final Function(String error) onCameraError;
  final Function() onCameraSuccess;

  /// Called once the camera is initialized with the preview aspect ratio
  /// (long side / short side), needed to project POIs onto the preview.
  final ValueChanged<double>? onPreviewAspectRatio;

  @override
  State<ArCamera> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCamera> with WidgetsBindingObserver {
  CameraController? controller;

  bool isCameraAuthorize = false;
  bool isCameraInitialize = false;

  /// Bumped whenever the camera is (re)started or released. An
  /// initialization that finishes after its generation became stale (app
  /// sent to background, widget disposed) releases its own controller
  /// instead of installing it.
  int _generation = 0;

  bool _isStarting = false;

  /// True when the camera was released because the app left the
  /// foreground, so it must be restarted on resume. Kept separate from
  /// "no controller yet" because the permission dialog also makes the app
  /// inactive/resumed, and must not trigger a second initialization.
  bool _releasedForBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    controller?.dispose();
    super.dispose();
  }

  /// The platform releases the camera when the app goes to background
  /// (mandatory on Android), leaving a frozen/errored preview on return
  /// unless the controller is disposed and recreated.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller != null || _isStarting) {
        _releaseCamera();
      }
    } else if (state == AppLifecycleState.resumed && _releasedForBackground) {
      _releasedForBackground = false;
      _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraAuthorize) {
      return const Center(
        child: Text('Need camera authorization'),
      );
    }
    final controller = this.controller;
    if (!isCameraInitialize || controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return SizedBox(
          width: size.width,
          height: size.height,
          child: ClipRect(
            child: Transform.scale(
              scale: _coverScale(size, controller.value.aspectRatio),
              child: Center(child: CameraPreview(controller)),
            ),
          ),
        );
      },
    );
  }

  /// Scale that makes the preview cover [size] (like [BoxFit.cover]).
  /// [CameraPreview] is letterboxed by default; [previewAspectRatio] is the
  /// sensor's landscape ratio, which [CameraPreview] flips in portrait.
  double _coverScale(Size size, double previewAspectRatio) {
    final displayedRatio =
        size.width > size.height ? previewAspectRatio : 1 / previewAspectRatio;
    final ratio = size.aspectRatio / displayedRatio;
    return ratio < 1 ? 1 / ratio : ratio;
  }

  Future<void> _initializeCamera() async {
    final isGranted = await _requestCameraAuthorization();
    if (!mounted) return;
    setState(() => isCameraAuthorize = isGranted);
    if (!isGranted) {
      widget.onCameraError('Camera need authorization permission');
      return;
    }
    await _startCamera();
  }

  Future<void> _startCamera() async {
    final generation = ++_generation;
    _isStarting = true;
    CameraController? newController;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', null);
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // `high` (720p) is plenty for a background preview; `max` wastes
      // memory, battery and thermal budget.
      newController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await newController.initialize();
    } catch (ex) {
      await newController?.dispose();
      if (!mounted || generation != _generation) return;
      _isStarting = false;
      setState(() => isCameraInitialize = false);
      widget.onCameraError('On error when camera initialize');
      return;
    }

    if (!mounted || generation != _generation) {
      await newController.dispose();
      return;
    }
    _isStarting = false;
    setState(() {
      controller = newController;
      isCameraInitialize = true;
    });
    widget.onPreviewAspectRatio?.call(newController.value.aspectRatio);
    widget.onCameraSuccess();
  }

  void _releaseCamera() {
    final oldController = controller;
    _generation++;
    _isStarting = false;
    _releasedForBackground = true;
    setState(() {
      controller = null;
      isCameraInitialize = false;
    });
    oldController?.dispose();
  }

  Future<bool> _requestCameraAuthorization() async {
    if (await Permission.camera.isGranted) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
