// lib/widgets/bet/bet_status_banner.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/bet_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/bet_status_helper.dart';
import '../../models/bet_model.dart';
import '../../screens/bet/bet_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/bet_service.dart';
import '../../services/voucher_service.dart';

class BetStatusBanner extends StatefulWidget {
  final BetModel bet;  // ✅ Recibir el bet completo
  final VoidCallback? onRefresh;

  const BetStatusBanner({
    super.key,
    required this.bet,
    this.onRefresh,
  });

  @override
  State<BetStatusBanner> createState() => _BetStatusBannerState();
}

class _BetStatusBannerState extends State<BetStatusBanner> {
  bool _isLoading = false;
  String _voucherCode = '';

  String getDescription() {
    switch (widget.bet.status) {
      case BetStatus.pendingPayment:
        return 'Debes confirmar el pago antes del cierre de apuestas.';
      case BetStatus.active:
        return 'Tu apuesta está participando actualmente.';
      case BetStatus.winner:
        return 'Felicidades, esta apuesta resultó ganadora.';
      case BetStatus.completed:
        return 'La jornada ya finalizó.';
      default:
        return 'Estado de apuesta.';
    }
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Selecciona método de pago',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildPaymentOption(
              icon: Icons.chat,
              color: Colors.green,
              title: 'Pagar por WhatsApp',
              subtitle: 'Envía mensaje y pagas por transferencia',
              onTap: () => _payWithWhatsApp(),
            ),

            const SizedBox(height: 12),

            _buildPaymentOption(
              icon: Icons.card_giftcard,
              color: Colors.orange,
              title: 'Pagar con Vale',
              subtitle: 'Usa un código de descuento',
              onTap: () => _showVoucherDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _payWithWhatsApp() async {
    final phone = AppConstants.whatsappNumber;
    final message = Uri.encodeComponent(
        AppConstants.paymentWhatsAppMessage
            .replaceAll('{betId}', widget.bet.id)
            .replaceAll('{userId}', widget.bet.uid)
            .replaceAll('{date}', DateTime.now().toString())
    );
    final url = Uri.parse('https://wa.me/$phone?text=$message');

    try {
      await launchUrl(url);
      // ✅ Cerrar bottom sheet
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al abrir WhatsApp'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showVoucherDialog() {
    _voucherCode = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Ingresa tu vale', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa el código de tu vale para pagar esta apuesta',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
              onChanged: (value) => _voucherCode = value.toUpperCase().trim(),
              decoration: InputDecoration(
                hintText: 'XXXX-XXXX-XXXX-XX',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: _redeemVoucher,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('PAGAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _redeemVoucher() async {
    if (_voucherCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un código de vale'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // ✅ Cerrar el diálogo del vale
    Navigator.pop(context);

    try {
      final voucherService = VoucherService();
      final success = await voucherService.redeemVoucher(
        code: _voucherCode,
        userId: widget.bet.uid,
        betId: widget.bet.id,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        // ✅ Cerrar el bottom sheet de métodos de pago
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // ✅ Mostrar snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vale aplicado. ¡Apuesta pagada!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );

        // ✅ Refrescar la pantalla
        widget.onRefresh?.call();

        // ✅ Volver al home después de 1.5 segundos
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context); // Cierra BetDetailScreen
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Vale inválido, expirado o ya usado'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Excepción: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Eliminar apuesta', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que quieres eliminar esta apuesta?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await BetService().deleteBet(widget.bet.id);
                await AnalyticsService.logBetDeleted(betId: widget.bet.id);
                if (!mounted) return;
                widget.onRefresh?.call();
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = BetStatusHelper.getText(widget.bet.status);
    final statusColor = BetStatusHelper.getColor(widget.bet.status);
    final statusIcon = BetStatusHelper.getIcon(widget.bet.status);
    final isPending = widget.bet.status == BetStatus.pendingPayment;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header con estado
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.18),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getDescription(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Botones de acción según estado
          if (isPending) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),

            // Botón PAGAR (verde)
            GestureDetector(
              onTap: _showPaymentOptions,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.green, Color(0xFF00C853)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '💳 PAGAR AHORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Botones EDITAR y ELIMINAR en fila
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      // ✅ Pasar la apuesta completa para edición
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BetScreen(betToEdit: widget.bet),
                        ),
                      );
                      if (result == true) {
                        widget.onRefresh?.call();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Center(
                        child: Text(
                          '✏️ EDITAR',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _showDeleteConfirmation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Text(
                          '🗑️ ELIMINAR',
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Botón para apuestas activas (compartir)
          if (widget.bet.status == BetStatus.active) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // TODO: Compartir apuesta
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Center(
                  child: Text(
                    '📤 COMPARTIR APUESTA',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(color: AppColors.primaryPurple),
            ),
        ],
      ),
    );
  }
}