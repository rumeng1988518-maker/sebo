import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _keyUploadToken = 'upload_token';
  static const _keyUserId = 'user_id';
  static const _keyRegistered = 'is_registered';
  static const _keyPhone = 'phone';
  static const _keyStep = 'registration_step';

  static Future<void> saveUploadToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUploadToken, token);
  }

  static Future<String?> getUploadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUploadToken);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> setRegistered(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRegistered, value);
  }

  static Future<bool> isRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRegistered) ?? false;
  }

  static Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<void> saveStep(int step) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStep, step);
  }

  static Future<int> getStep() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyStep) ?? 0;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
