// lib/core/constants/app_constants.dart
class AppConstants {
  // Número de WhatsApp para pagos (formato internacional sin +)
  static const String whatsappNumber = '573146841818';

  // Mensaje por defecto para pagos
  static const String paymentWhatsAppMessage = '''
Hola! Quiero pagar mi apuesta

🔹 ID Apuesta: {betId}
🔹 Monto: 5,000 COP
🔹 Usuario: {userId}

📅 Fecha: {date}
''';
}