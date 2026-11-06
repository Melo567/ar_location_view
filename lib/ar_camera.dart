import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why [ArCamera] cannot show the camera preview.
enum ArCameraErrorType {
  /// Camera permission was denied. The preview starts by itself once the
  /// permission is granted from the system settings.
  permissionDenied,

  /// No camera is available, or it failed to initialize. Initialization is
  /// retried when the app returns to the foreground.
  unavailable,
}

/// Builds the widget shown instead of the camera preview because of [error].
typedef ArCameraErrorBuilder =
    Widget Function(BuildContext context, ArCameraErrorType error);

enum _CameraStatus {
  requestingPermission,
  permissionDenied,
  starting,
  ready,
  failed,
}

class ArCamera extends StatefulWidget {
  const ArCamera({
    super.key,
    required this.onCameraError,
    required this.onCameraSuccess,
    this.onPreviewAspectRatio,
    this.errorBuilder,
  });

  final Function(String error) onCameraError;
  final Function() onCameraSuccess;

  /// Called once the camera is initialized with the preview aspect ratio
  /// (long side / short side), needed to project POIs onto the preview.
  final ValueChanged<double>? onPreviewAspectRatio;

  /// Widget shown when the camera permission is denied or the camera is
  /// unavailable. Defaults to a short message.
  final ArCameraErrorBuilder? errorBuilder;

  @override
  State<ArCamera> createState() => _ArCameraViewState();
}

class _ArCameraViewState extends State<ArCamera> with WidgetsBindingObserver {
  CameraController? controller;

  _CameraStatus _status = _CameraStatus.requestingPermission;

  /// Bumped whenever the camera is (re)started or released. An
  /// initialization that finishes after its generation became stale (app
  /// sent to background, widget disposed) releases its own controller
  /// instead of installing it.
  int _generation = 0;

  bool _isStarting = false;

  bool _isRecheckingPermission = false;

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
    } else if (state == AppLifecycleState.resumed) {
      if (_releasedForBackground) {
        _releasedForBackground = false;
        _startCamera();
      } else if (_status == _CameraStatus.permissionDenied) {
        // The user may come back from the system settings.
        _recheckPermission();
      } else if (_status == _CameraStatus.failed && !_isStarting) {
        _startCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _CameraStatus.permissionDenied:
        return _error(context, ArCameraErrorType.permissionDenied);
      case _CameraStatus.failed:
        return _error(context, ArCameraErrorType.unavailable);
      case _CameraStatus.ready:
        final controller = this.controller;
        if (controller != null) return _preview(controller);
        return _loading();
      case _CameraStatus.requestingPermission:
      case _CameraStatus.starting:
        return _loading();
    }
  }

  Widget _preview(CameraController controller) {
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

  Widget _loading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _error(BuildContext context, ArCameraErrorType error) {
    final builder = widget.errorBuilder;
    if (builder != null) return builder(context, error);
    final message = error == ArCameraErrorType.permissionDenied
        ? 'Camera permission denied'
        : 'Camera unavailable';
    return Center(child: Text(message, textAlign: TextAlign.center));
  }

  /// Scale that makes the preview cover [size] (like [BoxFit.cover]).
  /// [CameraPreview] is letterboxed by default; [previewAspectRatio] is the
  /// sensor's landscape ratio, which [CameraPreview] flips in portrait.
  double _coverScale(Size size, double previewAspectRatio) {
    final displayedRatio = size.width > size.height
        ? previewAspectRatio
        : 1 / previewAspectRatio;
    final ratio = size.aspectRatio / displayedRatio;
    return ratio < 1 ? 1 / ratio : ratio;
  }

  Future<void> _initializeCamera() async {
    final isGranted = await _requestCameraAuthorization();
    if (!mounted) return;
    if (!isGranted) {
      setState(() => _status = _CameraStatus.permissionDenied);
      widget.onCameraError('Camera need authorization permission');
      return;
    }
    await _startCamera();
  }

  /// Only checks the permission, without prompting again: showing the
  /// dialog on every resume would be intrusive.
  Future<void> _recheckPermission() async {
    if (_isRecheckingPermission) return;
    _isRecheckingPermission = true;
    try {
      final isGranted = await Permission.camera.isGranted;
      if (!mounted || !isGranted || _status != _CameraStatus.permissionDenied) {
        return;
      }
      await _startCamera();
    } finally {
      _isRecheckingPermission = false;
    }
  }

  Future<void> _startCamera() async {
    final generation = ++_generation;
    _isStarting = true;
    if (mounted && _status != _CameraStatus.starting) {
      setState(() => _status = _CameraStatus.starting);
    }
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
      setState(() => _status = _CameraStatus.failed);
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
      _status = _CameraStatus.ready;
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
      _status = _CameraStatus.starting;
    });
    oldController?.dispose();
  }

  Future<bool> _requestCameraAuthorization() async {
    if (await Permission.camera.isGranted) return true;
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}
