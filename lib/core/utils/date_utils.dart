// lib/core/utils/date_utils.dart

class DateUtilsApp {
  // Formatear fecha para mostrar en cards
  static String formatMatchDateTime(DateTime dateTime) {
    // dateTime ya está en hora Colombia desde Firestore
    final days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final dayName = days[dateTime.weekday - 1];
    final monthName = months[dateTime.month - 1];
    final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dayName, ${dateTime.day} de $monthName - $time';
  }

  // Calcular tiempo restante
  static String getRemainingTime(DateTime matchTime) {
    final now = DateTime.now();
    final diff = matchTime.difference(now);

    if (diff.isNegative) return 'Cerrado';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }

  // Formato fecha corta para historial
  static String formatDateShort(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  // Formato hora
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}