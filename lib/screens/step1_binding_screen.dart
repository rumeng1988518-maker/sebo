import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/device_info_helper.dart';
import 'step2_avatar_screen.dart';

class Step1BindingScreen extends StatefulWidget {
  const Step1BindingScreen({super.key});

  @override
  State<Step1BindingScreen> createState() => _Step1BindingScreenState();
}

class _Step1BindingScreenState extends State<Step1BindingScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLocating = true;
  String _locationStatus = '正在获取定位权限...';
  Position? _position;

  @override
  void initState() {
    super.initState();
    _requestLocationAndFetch();
  }

  Future<void> _requestLocationAndFetch() async {
    try {
      final status = await Permission.locationWhenInUse.request();
      if (!status.isGranted) {
        setState(() {
          _isLocating = false;
          _locationStatus = '定位权限未开启，将跳过定位信息';
        });
        return;
      }

      setState(() => _locationStatus = '正在获取当前位置...');

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocating = false;
          _locationStatus = '定位服务未开启';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() {
        _position = position;
        _isLocating = false;
        _locationStatus =
            '定位成功：(${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
      });
    } catch (e) {
      setState(() {
        _isLocating = false;
        _locationStatus = '定位不可用，将继续下一步';
      });
    }
  }

  Map<String, dynamic>? _buildLocation() {
    if (_position == null) return null;
    return {
      'latitude': _position!.latitude,
      'longitude': _position!.longitude,
      'accuracy': _position!.accuracy,
      'timestamp': _position!.timestamp.toIso8601String(),
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeController.text.trim();

    setState(() => _isLoading = true);

    try {
      final existingToken = await StorageService.getUploadToken();

      final verifyResult = await ApiService.verifyInviteCode(
        code,
        existingToken: existingToken,
      );

      if (verifyResult['code'] != 0) {
        _showError(verifyResult['message'] ?? '绑定码无效');
        return;
      }

      final data = verifyResult['data'] as Map<String, dynamic>? ?? {};

      if (data['reuseSession'] == true) {
        final uploadToken = data['uploadToken'] as String;
        ApiService.setUploadToken(uploadToken);
        await StorageService.saveUploadToken(uploadToken);

        final phone = data['phone'] as String?;
        if (phone != null) {
          await StorageService.savePhone(phone);
        }

        if (!mounted) return;
        Navigator.of(context)
            .pushReplacement(_slideRoute(const Step2AvatarScreen()));
        return;
      }

      final deviceInfo = await DeviceInfoHelper.getDeviceInfo();
      final location = _buildLocation();

      final registerResult = await ApiService.anonymousRegister(
        inviteCode: code,
        location: location,
        deviceInfo: deviceInfo,
      );

      if (registerResult['code'] != 0) {
        _showError(registerResult['message'] ?? '注册失败');
        return;
      }

      final regData = registerResult['data'] as Map<String, dynamic>;
      final uploadToken = regData['uploadToken'] as String;
      final userId = regData['userId'] as String;

      ApiService.setUploadToken(uploadToken);
      await StorageService.saveUploadToken(uploadToken);
      await StorageService.saveUserId(userId);

      // Sync device info in background if we got location after registering
      if (location == null && _position != null) {
        _syncDeviceInBackground(deviceInfo);
      }

      if (!mounted) return;
      Navigator.of(context)
          .pushReplacement(_slideRoute(const Step2AvatarScreen()));
    } catch (e) {
      _showError('网络异常，请检查连接后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncDeviceInBackground(Map<String, dynamic> deviceInfo) async {
    try {
      await ApiService.syncDevice(
        location: _buildLocation(),
        deviceInfo: deviceInfo,
      );
    } catch (_) {}
  }

  void _showError(String msg) {
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

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildStepIndicator(1),
                const SizedBox(height: 32),
                const Text(
                  '绑定设备',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入设备绑定码，完成当前设备注册',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                _buildLocationCard(),
                const SizedBox(height: 28),
                const Text(
                  '设备绑定码',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 3,
                  ),
                  decoration: const InputDecoration(
                    hintText: '请输入绑定码',
                    prefixIcon: Icon(
                      Icons.vpn_key_rounded,
                      color: Color(0xFF6C5CE7),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '绑定码不能为空';
                    }
                    return null;
                  },
                ),
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
                      : const Text('下一步'),
                ),
                const SizedBox(height: 20),
              ],
            ),
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

  Widget _buildLocationCard() {
    final bool hasLocation = _position != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasLocation
            ? const Color(0xFF6C5CE7).withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasLocation
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasLocation
                  ? const Color(0xFF6C5CE7).withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasLocation
                  ? Icons.location_on_rounded
                  : Icons.location_searching_rounded,
              color: hasLocation ? const Color(0xFF6C5CE7) : Colors.grey[500],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation ? '定位已获取' : '位置信息',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasLocation
                        ? const Color(0xFF6C5CE7)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _locationStatus,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (_isLocating)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
