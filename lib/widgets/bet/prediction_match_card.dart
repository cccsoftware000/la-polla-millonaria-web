import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';

class PredictionMatchCard extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final String homeLogo;
  final String awayLogo;
  final int homeScore;
  final int awayScore;

  const PredictionMatchCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.homeScore,
    required this.awayScore,
  });

  Widget _buildTeamLogo(String logoUrl, String teamName, double size) {
    // Si es una URL de internet (empieza con http)
    if (logoUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryPurple,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              teamName.isNotEmpty ? teamName.substring(0, 1) : '⚽',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      );
    }

    // Si es emoji o texto plano
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          logoUrl,
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Equipo Local
          Expanded(
            child: Column(
              children: [
                _buildTeamLogo(homeLogo, homeTeam, 48),
                const SizedBox(height: 8),
                Text(
                  homeTeam,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Marcador
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '$homeScore - $awayScore',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Equipo Visitante
          Expanded(
            child: Column(
              children: [
                _buildTeamLogo(awayLogo, awayTeam, 48),
                const SizedBox(height: 8),
                Text(
                  awayTeam,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}