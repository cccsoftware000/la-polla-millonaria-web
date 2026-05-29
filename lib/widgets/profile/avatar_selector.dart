import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AvatarSelector extends StatelessWidget {
  final String selectedAvatar;
  final Function(String) onAvatarSelected;

  const AvatarSelector({
    super.key,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  static const List<String> avatars = [
    '⚽', '🏆', '🔥', '⭐', '💪', '🎯', '🚀', '👑',
    '🐺', '🦅', '🐯', '🦁', '🐍', '🐉', '⚡', '🌟',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ELIGE TU AVATAR',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: avatars.map((avatar) {
            final isSelected = avatar == selectedAvatar;
            return GestureDetector(
              onTap: () => onAvatarSelected(avatar),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.energeticRed],
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    avatar,
                    style: TextStyle(
                      fontSize: 28,
                      shadows: isSelected
                          ? [
                        Shadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}