import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final info = <String, dynamic>{};

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        info['platform'] = 'android';
        info['brand'] = androidInfo.brand;
        info['model'] = androidInfo.model;
        info['device'] = androidInfo.device;
        info['androidVersion'] = androidInfo.version.release;
        info['sdkInt'] = androidInfo.version.sdkInt;
        info['manufacturer'] = androidInfo.manufacturer;
        info['product'] = androidInfo.product;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
        info['id'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        info['platform'] = 'ios';
        info['name'] = iosInfo.name;
        info['model'] = iosInfo.model;
        info['systemName'] = iosInfo.systemName;
        info['systemVersion'] = iosInfo.systemVersion;
        info['identifierForVendor'] = iosInfo.identifierForVendor;
        info['isPhysicalDevice'] = iosInfo.isPhysicalDevice;
        info['utsname'] = {
          'machine': iosInfo.utsname.machine,
          'nodename': iosInfo.utsname.nodename,
        };
      }
    } catch (_) {}

    return info;
  }
}
