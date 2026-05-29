// lib/widgets/confirmation_dialog.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class ConfirmationDialog {
  static Future<bool?> show(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'CONFIRMAR',
        String cancelText = 'CANCELAR',
        bool isDestructive = false,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              cancelText,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.redAccent : AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              confirmText,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}