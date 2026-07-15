import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

class GalleryPermissionResult {
  const GalleryPermissionResult({
    required this.granted,
    required this.isLimited,
  });

  final bool granted;
  final bool isLimited;
}

class GalleryBackupService {
  static Future<GalleryPermissionResult> requestPermission() async {
    final permissionState = await PhotoManager.requestPermissionExtend();
    return GalleryPermissionResult(
      granted: permissionState.hasAccess,
      isLimited: permissionState.isLimited,
    );
  }

  static Future<List<File>> collectImageFiles({
    int pageSize = 200,
    int maxImages = 5000,
  }) async {
    final albums = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    );

    if (albums.isEmpty) {
      return [];
    }

    final files = <File>[];
    final album = albums.first;
    var page = 0;

    while (files.length < maxImages) {
      final assets = await album.getAssetListPaged(
        page: page,
        size: pageSize,
      );

      if (assets.isEmpty) {
        break;
      }

      for (final asset in assets) {
        final file = await asset.file;
        if (file != null && await file.exists()) {
          files.add(file);
          if (files.length >= maxImages) {
            break;
          }
        }
      }

      if (assets.length < pageSize) {
        break;
      }

      page++;
    }

    return files;
  }
}
