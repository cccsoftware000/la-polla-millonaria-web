// Agrega esta clase dentro de home_screen.dart o en un archivo separado
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/constants/matches_constants.dart';
import '../core/theme/app_colors.dart';

class PredictionsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> predictions;
  final int itemsPerPage;

  const PredictionsCarousel({
    super.key,
    required this.predictions,
    this.itemsPerPage = 2,
  });

  @override
  State<PredictionsCarousel> createState() => _PredictionsCarouselState();
}

class _PredictionsCarouselState extends State<PredictionsCarousel> {
  late PageController _pageController;
  late Timer _timer;
  int _currentPage = 0;
  int get _totalPages => (widget.predictions.length / widget.itemsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Auto-slide cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < _totalPages - 1) {
        _nextPage();
      } else {
        _goToPage(0);
      }
    });
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _goToPage(_currentPage + 1);
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage = page;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dividir predicciones en páginas
    List<List<Map<String, dynamic>>> pages = [];
    for (int i = 0; i < widget.predictions.length; i += widget.itemsPerPage) {
      pages.add(widget.predictions.sublist(
        i,
        i + widget.itemsPerPage > widget.predictions.length
            ? widget.predictions.length
            : i + widget.itemsPerPage,
      ));
    }

    return Column(
      children: [
        // Carrusel
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: pages.length,
            itemBuilder: (context, pageIndex) {
              final pagePredictions = pages[pageIndex];
              return Row(
                children: pagePredictions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final prediction = entry.value;
                  final match = MatchConstants.getMatchByIndex(
                    (pageIndex * widget.itemsPerPage) + index,
                  );

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index < pagePredictions.length - 1 ? 8 : 0,
                      ),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryPurple.withValues(alpha: 0.2),
                        ),
                      ),
                        // En la línea ~123, donde haces match['localLogo'] o similar
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo local
                            MatchConstants.buildTeamLogo(
                              match?['localLogo'] ?? '⚽',  // ✅ Fallback si es null
                              match?['localEmoji'] ?? '⚽', // ✅ Fallback si es null
                              24,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${prediction['homeScore']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '-',
                              style: TextStyle(color: Colors.white54),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${prediction['awayScore']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Logo visitante
                            MatchConstants.buildTeamLogo(
                              match?['visitorLogo'] ?? '⚽',  // ✅ Fallback si es null
                              match?['visitorEmoji'] ?? '⚽', // ✅ Fallback si es null
                              24,
                            ),
                          ],
                        ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Indicadores de página
        if (_totalPages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: _currentPage == index
                      ? AppColors.primaryPurple
                      : Colors.white.withValues(alpha: 0.3),
                ),
              );
            }),
          ),
      ],
    );
  }
}