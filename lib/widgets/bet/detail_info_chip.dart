import 'package:flutter/material.dart';

class DetailInfoChip
    extends StatelessWidget {

  final IconData icon;

  final String label;

  final String value;

  const DetailInfoChip({

    super.key,

    required this.icon,

    required this.label,

    required this.value,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      decoration: BoxDecoration(

        color: Colors.white.withValues(
          alpha: 0.05,
        ),

        borderRadius:
        BorderRadius.circular(22),

        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Container(

            width: 42,
            height: 42,

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              color: Colors.white.withValues(
                alpha: 0.06,
              ),
            ),

            child: Icon(

              icon,

              color: Colors.white,

              size: 22,
            ),
          ),

          const SizedBox(width: 14),

          Column(

            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [

              Text(

                label,

                style: TextStyle(
                  color: Colors.white
                      .withValues(
                    alpha: 0.55,
                  ),

                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 4),

              Text(

                value,

                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}