import 'package:flutter/material.dart';

import '../constants/bet_status.dart';

class BetStatusHelper {

  static String getText(String status) {

    switch (status) {

      case BetStatus.pendingPayment:
        return 'Pendiente de pago';

      case BetStatus.active:
        return 'Activa';

      case BetStatus.winner:
        return 'Ganadora';

      case BetStatus.completed:
        return 'Finalizada';

      default:
        return status;
    }
  }

  static Color getColor(String status) {

    switch (status) {

      case BetStatus.pendingPayment:
        return Colors.orange;

      case BetStatus.active:
        return Colors.green;

      case BetStatus.winner:
        return Colors.greenAccent;

      case BetStatus.completed:
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  static IconData getIcon(String status) {

    switch (status) {

      case BetStatus.pendingPayment:
        return Icons.access_time;

      case BetStatus.active:
        return Icons.play_circle_outline;

      case BetStatus.winner:
        return Icons.emoji_events;

      case BetStatus.completed:
        return Icons.check_circle_outline;

      default:
        return Icons.info_outline;
    }
  }
}