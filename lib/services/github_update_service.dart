import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/utils/ReleaseInfo.dart';

class GitHubUpdateService {
  static const String GITHUB_USER = 'cccsoftware000';
  static const String GITHUB_REPO = 'la-polla-millonaria-updates';
  static const String? GITHUB_TOKEN = null;

  static const String API_URL =
      'https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest';

  Future<ReleaseInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('📱 Versión actual: $currentVersion');
      print('🔍 Buscando actualizaciones en GitHub...');

      final headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'LaPollaMillonariaApp',
      };

      if (GITHUB_TOKEN != null) {
        headers['Authorization'] = 'token $GITHUB_TOKEN';
      }

      final response = await http.get(
        Uri.parse(API_URL),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name'].toString().replaceFirst('v', '');
        final releaseNotes = data['body'] ?? '';
        final publishDate = data['published_at'];

        final assets = data['assets'] as List;
        final apkAsset = assets.firstWhere(
              (asset) => asset['name'].toString().endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset == null) {
          print('❌ No se encontró APK en el release');
          return null;
        }

        final apkName = apkAsset['name'] as String;
        final directDownloadUrl = 'https://github.com/$GITHUB_USER/$GITHUB_REPO/releases/download/v$latestVersion/$apkName';
        final apkSize = apkAsset['size'] ?? 0;

        print('📊 Última versión: $latestVersion');
        print('📦 Tamaño APK: ${(apkSize / 1024 / 1024).toStringAsFixed(2)} MB');

        final needsUpdate = _isNewerVersion(currentVersion, latestVersion);
        final isRequired = _isRequiredUpdate(currentVersion, latestVersion);

        if (needsUpdate) {
          return ReleaseInfo(
            version: latestVersion,
            apkUrl: directDownloadUrl,
            apkSize: apkSize,
            releaseNotes: releaseNotes,
            publishDate: publishDate,
            isRequired: isRequired,
          );
        }
      }
      return null;
    } catch (e) {
      print('❌ Error checking updates: $e');
      return null;
    }
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  bool _isRequiredUpdate(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      if (latestParts[0] > currentParts[0]) return true;
      if (latestParts[1] > currentParts[1] + 1) return true;

      return false;
    } catch (e) {
      return false;
    }
  }

  // ✅ Método simplificado - sin permisos de almacenamiento
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // ✅ Solo pedir permiso de instalación de apps desconocidas
      final installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          print('⚠️ Permiso de instalación denegado, el usuario tendrá que instalar manualmente');
          return true; // No bloqueamos, solo advertimos
        }
      }

      return true;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return true; // Continuamos de todas formas
    }
  }

  Future<bool> downloadAndInstall(String apkUrl, BuildContext context,
      {Function(double)? onProgress}) async {
    // ✅ No necesitamos permisos de almacenamiento porque usamos directorio de la app
    await requestPermissions();

    // ✅ Usar getApplicationDocumentsDirectory (no requiere permisos especiales)
    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'la_polla_millonaria_v${DateTime.now().millisecondsSinceEpoch}.apk';
    final filePath = '${directory.path}/$fileName';

    print('📥 Descargando APK desde: $apkUrl');
    print('📁 Guardando en: $filePath');

    http.Client? client;

    try {
      client = http.Client();

      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] = 'LaPollaMillonariaApp';

      final response = await client.send(request).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Timeout de conexión (60 segundos)');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;
      var lastProgress = 0.0;

      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        if (totalBytes != null && totalBytes > 0 && onProgress != null) {
          final progress = receivedBytes / totalBytes;
          if (progress - lastProgress > 0.05 || progress >= 1.0) {
            lastProgress = progress;
            onProgress(progress);
          }
        }
      }

      await sink.close();
      client.close();

      final fileSize = await file.length();
      print('✅ APK descargada: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (fileSize == 0) {
        throw Exception('El archivo descargado está vacío');
      }

      // ✅ Abrir la APK para instalación
      final result = await OpenFile.open(filePath);
      print('📱 Resultado instalación: ${result.type}');

      return result.type == ResultType.done;
    } catch (e) {
      print('❌ Error: $e');
      if (client != null) client.close();
      return false;
    }
  }
}