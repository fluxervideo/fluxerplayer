// FluxerPlayer: la suscripción de Fluxer en el menú del usuario (al pulsar la
// foto). En tele y ordenador, tarjeta al lado de los perfiles; en el móvil,
// versión compacta debajo del nombre.
//
// Datos de FluxerHub (api/app/me): plan, estado, hasta cuándo dura, si se
// renueva solo, saldo, email y servidor. «Renovar» y «Mi cuenta» abren el
// portal ya con la sesión iniciada (fluxer_portal.dart). Sin vincular, nada.
//
// Enganches: lib/ui/widgets/user_menu_dialog.dart y left_sidebar.dart
// (`// FLUXER:`); también Ajustes → Mi cuenta Fluxer (fluxer_account_screen.dart).

import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';
import 'fluxer_recharge_screen.dart';

class FluxerSubscriptionCard extends StatefulWidget {
  const FluxerSubscriptionCard({
    super.key,
    this.compact = false,
    this.sidebar = false,
    this.fill = false,
    this.autofocus = false,
  });

  /// Móvil: líneas bajo el nombre, sin caja ni botones grandes.
  final bool compact;

  /// Barra lateral (tele/ordenador): bloque pequeño bajo el usuario, sin botones.
  final bool sidebar;

  /// Ocupa todo el ancho que le den (Ajustes → Mi cuenta Fluxer).
  final bool fill;

  /// «Renovar» con el foco al abrir (mando de la tele).
  final bool autofocus;

  @override
  State<FluxerSubscriptionCard> createState() => _FluxerSubscriptionCardState();
}

class _FluxerSubscriptionCardState extends State<FluxerSubscriptionCard> {
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    FluxerHubClient.instance.me().then((me) {
      if (mounted && me != null) setState(() => _me = me);
    });
  }

  Map<String, dynamic>? _map(String key) => (_me?[key] as Map?)?.cast<String, dynamic>();

  @override
  Widget build(BuildContext context) {
    final me = _me;
    if (me == null) return const SizedBox.shrink();
    final s = FluxerStrings.of(context);
    final plan = _map('plan');
    final customer = _map('customer');
    final server = _map('server');

    final status = plan?['status'] as String? ?? '';
    final endsAt = DateTime.tryParse(plan?['ends_at'] as String? ?? '')?.toLocal();
    final days = endsAt == null ? null : (endsAt.difference(DateTime.now()).inHours / 24).ceil();
    final renewsAlone = (plan?['auto_renew'] as bool? ?? false) &&
        (plan?['balance_covers_next_renewal'] as bool? ?? false);
    final email = customer?['email'] as String?;
    final balance = (customer?['balance'] as num?)?.toDouble();

    // Verde activo; ámbar si caduca en ≤7 días sin renovarse solo; rojo si no está activo.
    final Color tone;
    final String label;
    if (status != 'active') {
      tone = AppColorScheme.statusRequested;
      label = plan?['status_label'] as String? ?? s.noPlan;
    } else if (days != null && days <= 7 && !renewsAlone) {
      tone = const Color(0xFFF5A623);
      label = s.subscriptionEndsInDays(days);
    } else {
      tone = AppColorScheme.statusAvailable;
      label = s.subscriptionActive;
    }

    final rows = <(IconData, String)>[
      if (endsAt != null)
        (Icons.event, renewsAlone || plan?['auto_renew'] == true ? s.renewsOn(endsAt) : s.endsOn(endsAt)),
      (Icons.autorenew, plan?['auto_renew'] == true ? s.autoRenewYes : s.autoRenewNo),
      if (balance != null) (Icons.account_balance_wallet_outlined, s.balance(balance)),
      if (email != null && email.isNotEmpty) (Icons.mail_outline, email),
      if (server?['name'] != null) (Icons.dns_outlined, '${server!['name']} · ${server['status_label'] ?? ''}'),
    ];

    if (widget.sidebar) return _sidebar(s, plan, tone, label, endsAt, renewsAlone || plan?['auto_renew'] == true, balance);
    return widget.compact ? _compact(s, plan, tone, label, rows) : _wide(s, plan, tone, label, rows);
  }

  Widget _sidebar(
    FluxerStrings s,
    Map<String, dynamic>? plan,
    Color tone,
    String label,
    DateTime? endsAt,
    bool renews,
    double? balance,
  ) {
    final muted = Colors.white.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  plan?['name'] as String? ?? s.noPlan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              endsAt == null ? label : (renews ? s.renewsOn(endsAt) : s.endsOn(endsAt)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tone == AppColorScheme.statusAvailable ? muted : tone, fontSize: 12),
            ),
          ),
          if (balance != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                s.balanceLine(balance),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(Color tone, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: tone.withValues(alpha: 0.6)),
    ),
    child: Text(label, style: TextStyle(color: tone, fontWeight: FontWeight.w600, fontSize: 13)),
  );

  Widget _wide(FluxerStrings s, Map<String, dynamic>? plan, Color tone, String label, List<(IconData, String)> rows) {
    final muted = AppColorScheme.onSurface.withValues(alpha: 0.75);
    return Container(
      width: widget.fill ? null : 380,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons/app_icon.png', width: 28, height: 28),
              const SizedBox(width: 10),
              Text(
                s.yourSubscription,
                style: TextStyle(fontSize: 13, letterSpacing: 0.6, color: muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plan?['name'] as String? ?? s.noPlan,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          _chip(tone, label),
          const SizedBox(height: 18),
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 15, color: muted))),
                ],
              ),
            ),
          const SizedBox(height: 8),
          // Recargar saldo dentro de la app (fluxer_recharge_screen.dart);
          // planes y cuenta, en el portal.
          FilledButton.icon(
            autofocus: widget.autofocus,
            onPressed: () => openFluxerRecharge(context),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(s.recharge)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openFluxerPortal(context, 'plans', title: s.renew),
                  icon: const Icon(Icons.autorenew, size: 18),
                  label: Text(s.renew),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openFluxerPortal(context, 'account', title: s.fluxerAccount),
                  icon: const Icon(Icons.person_outline, size: 18),
                  label: Text(s.myAccount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compact(FluxerStrings s, Map<String, dynamic>? plan, Color tone, String label, List<(IconData, String)> rows) {
    final muted = AppColorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                plan?['name'] as String? ?? s.noPlan,
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColorScheme.onSurface),
              ),
              _chip(tone, label),
            ],
          ),
          const SizedBox(height: 6),
          for (final (icon, text) in rows.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: muted),
                  const SizedBox(width: 6),
                  Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: muted), overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => openFluxerRecharge(context),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: Text(s.recharge),
              ),
              TextButton.icon(
                onPressed: () => openFluxerPortal(context, 'plans', title: s.renew),
                icon: const Icon(Icons.autorenew, size: 16),
                label: Text(s.renew),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
