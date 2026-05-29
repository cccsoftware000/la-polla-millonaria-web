import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class LoadingBetDialog
    extends StatefulWidget {

  const LoadingBetDialog({
    super.key,
  });

  @override
  State<LoadingBetDialog> createState() =>
      _LoadingBetDialogState();
}

class _LoadingBetDialogState
    extends State<LoadingBetDialog>

    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(

      vsync: this,

      duration:
      const Duration(seconds: 2),

    )..repeat();
  }

  @override
  void dispose() {

    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(

      backgroundColor:
      AppColors.midnightBlue,

      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(28),
      ),

      child: Padding(

        padding: const EdgeInsets.all(30),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            RotationTransition(

              turns: controller,

              child: Container(

                width: 90,
                height: 90,

                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  gradient:
                  const LinearGradient(
                    colors: [
                      AppColors.primaryPurple,
                      AppColors.energeticRed,
                    ],
                  ),

                  boxShadow: [

                    BoxShadow(
                      color: AppColors
                          .primaryPurple
                          .withOpacity(0.45),

                      blurRadius: 30,
                    ),
                  ],
                ),

                child: const Center(
                  child: Text(
                    '⚽',
                    style: TextStyle(
                      fontSize: 44,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text(

              'Registrando apuesta',

              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(

              'Estamos validando tu jugada...',

              textAlign: TextAlign.center,

              style: TextStyle(
                color:
                Colors.white.withOpacity(0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}