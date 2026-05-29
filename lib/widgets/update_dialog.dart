// lib/widgets/update_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/ReleaseInfo.dart';
import '../services/github_update_service.dart';

class UpdateDialog extends StatefulWidget {
  final ReleaseInfo release;
  final VoidCallback onUpdate;

  const UpdateDialog({
    super.key,
    required this.release,
    required this.onUpdate,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'Preparando descarga...';
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // ✅ Si es obligatoria, no se puede cerrar con el botón de atrás
    return WillPopScope(
      onWillPop: () async => !widget.release.isRequired && !_isDownloading,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(
              _isDownloading ? Icons.downloading :
              (_hasError ? Icons.error_outline : Icons.system_update),
              color: _hasError ? Colors.redAccent : Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.release.isRequired ? '⚠️ ACTUALIZACIÓN OBLIGATORIA' : 'Nueva versión disponible',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: _isDownloading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        )
            : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Versión ${widget.release.version} • ${widget.release.formattedSize}',
                style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Novedades:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.release.releaseNotes,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (widget.release.isRequired && !_hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, size: 16, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta actualización es obligatoria para seguir usando la app',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (!_isDownloading && !widget.release.isRequired)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('MÁS TARDE', style: TextStyle(color: Colors.white54)),
            ),
          ElevatedButton(
            onPressed: (_isDownloading || _hasError) ? null : _startUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasError ? Colors.redAccent : Colors.orangeAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(_hasError ? 'REINTENTAR' : (_isDownloading ? 'DESCARGANDO...' : 'ACTUALIZAR AHORA')),
          ),
        ],
      ),
    );
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Conectando con servidor...';
      _hasError = false;
    });

    final service = GitHubUpdateService();

    try {
      final success = await service.downloadAndInstall(
        widget.release.apkUrl,
        context,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _statusMessage = 'Descargando... ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _statusMessage = 'Error en la descarga';
        });
      }
    } catch (e) {
      print('Error en actualización: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _statusMessage = 'Error: $e';
        });
      }
    }
  }
}