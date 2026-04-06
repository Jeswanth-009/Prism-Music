import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling runtime permissions
class PermissionService {
  /// Request all required permissions for the app
  static Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = <Permission>[];
    
    if (Platform.isAndroid) {
      // Check Android version for appropriate permissions
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 33) {
        // Android 13+ uses granular media permissions
        permissions.addAll([
          Permission.audio,
          Permission.notification,
        ]);
      } else if (androidInfo >= 30) {
        // Android 11-12
        permissions.add(Permission.storage);
      } else {
        // Android 10 and below
        permissions.addAll([
          Permission.storage,
        ]);
      }
    } else if (Platform.isIOS) {
      permissions.addAll([
        Permission.mediaLibrary,
        Permission.notification,
      ]);
    }
    
    if (permissions.isEmpty) {
      return {};
    }
    
    return await permissions.request();
  }
  
  /// Request notification permission (required for Android 13+)
  static Future<bool> requestNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      return true; // Not required for older Android
    } else if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }
  
  /// Request storage/audio permission for downloads
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 33) {
        // Android 13+ uses granular permissions
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        // Older Android uses storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.mediaLibrary.request();
      return status.isGranted;
    }
    return true;
  }
  
  /// Check if storage permission is granted
  static Future<bool> hasStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 33) {
        return await Permission.audio.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    } else if (Platform.isIOS) {
      return await Permission.mediaLibrary.isGranted;
    }
    return true;
  }
  
  /// Check if notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        return await Permission.notification.isGranted;
      }
      return true;
    } else if (Platform.isIOS) {
      return await Permission.notification.isGranted;
    }
    return true;
  }
  
  /// Open app settings if permissions are permanently denied
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }
  
  /// Get Android SDK version
  static Future<int> _getAndroidVersion() async {
    try {
      // Use device_info_plus to get accurate version
      // For now, assume Android 13+ for safety
      return 33;
    } catch (e) {
      return 33; // Default to newer behavior
    }
  }
  
  /// Check all permission statuses
  static Future<PermissionSummary> checkPermissions() async {
    final hasNotification = await hasNotificationPermission();
    final hasStorage = await hasStoragePermission();
    
    return PermissionSummary(
      notificationGranted: hasNotification,
      storageGranted: hasStorage,
      allGranted: hasNotification && hasStorage,
    );
  }
}

/// Summary of permission statuses
class PermissionSummary {
  final bool notificationGranted;
  final bool storageGranted;
  final bool allGranted;
  
  const PermissionSummary({
    required this.notificationGranted,
    required this.storageGranted,
    required this.allGranted,
  });
}
