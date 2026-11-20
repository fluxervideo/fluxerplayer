// FluxerPlayer: Tarjeta con los datos de la suscripción.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../auth/repositories/session_repository.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';
import 'fluxer_recharge_screen.dart';

/// Barra lateral: el usuario y la suscripción juntos en una tarjeta; el
/// fondo solo se ve con la barra abierta.
Widget fluxerSidebarAccountBox({required bool expanded, required Widget child}) => AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  // Sin margen a los lados con la barra cerrada: la fila del usuario no cabría.
  margin: EdgeInsets.fromLTRB(expanded ? 10 : 0, 10, expanded ? 10 : 0, 6),
  decoration: BoxDecoration(
    color: expanded ? const Color(0xFF262B33).withValues(alpha: 0.92) : Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: expanded ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
  ),
  child: child,
);

/// Fecha de fin que tiene sentido enseñar: los planes indefinidos llevan una
/// muy lejana.
DateTime? _visibleEnd(DateTime? endsAt) =>
    endsAt != null && endsAt.difference(DateTime.now()).inDays < 3650 ? endsAt : null;

class FluxerSubscriptionCard extends StatefulWidget {
  const FluxerSubscriptionCard({
    super.key,
    this.compact = false,
    this.sidebar = false,
    this.fill = false,
    this.autofocus = false,
    this.serverId,
    this.userId,
  });

  /// Móvil: líneas bajo el nombre, sin caja ni botones grandes.
  final bool compact;

  /// Barra lateral (tele/ordenador): bloque pequeño bajo el usuario, sin botones.
  final bool sidebar;

  /// Ocupa todo el ancho que le den (Ajustes → Mi cuenta Fluxer).
  final bool fill;

  /// «Recargar saldo» con el foco al abrir (mando de la tele).
  final bool autofocus;

  /// La suscripción de este usuario en vez de la del activo
  /// («Cambiar de usuario»).
  final String? serverId;
  final String? userId;

  @override
  State<FluxerSubscriptionCard> createState() => _FluxerSubscriptionCardState();
}

class _FluxerSubscriptionCardState extends State<FluxerSubscriptionCard> {
  Map<String, dynamic>? _me;

  int _load = 0;
  StreamSubscription<Object?>? _sessionChanges;
  String? _owner;

  static String? get _activeOwner {
    if (!GetIt.instance.isRegistered<SessionRepository>()) return null;
    final session = GetIt.instance<SessionRepository>();
    return '${session.activeServerId}:${session.activeUserId}';
  }

  @override
  void initState() {
    super.initState();
    _owner = _activeOwner;
    _fetch();
    // Sin usuario fijo sigue al activo: la barra lateral no se vuelve a
    // crear al cambiar de usuario.
    if (GetIt.instance.isRegistered<SessionRepository>()) {
      _sessionChanges = GetIt.instance<SessionRepository>().stateStream.listen((_) {
        final owner = _activeOwner;
        if (widget.userId != null || owner == _owner) return;
        _owner = owner;
        if (mounted) setState(() => _me = null);
        _fetch();
      });
    }
  }

  @override
  void dispose() {
    unawaited(_sessionChanges?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(FluxerSubscriptionCard old) {
    super.didUpdateWidget(old);
    if (old.serverId != widget.serverId || old.userId != widget.userId) {
      setState(() => _me = null);
      _fetch();
    }
  }

  void _fetch() {
    final load = ++_load;
    FluxerHubClient.instance.me(serverId: widget.serverId, userId: widget.userId).then((me) {
      if (mounted && load == _load && me != null) setState(() => _me = me);
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
    final endsAt = _visibleEnd(DateTime.tryParse(plan?['ends_at'] as String? ?? '')?.toLocal());
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

    if (widget.sidebar) {
      return _sidebar(s, plan, tone, label, endsAt, renewsAlone || plan?['auto_renew'] == true, balance, email);
    }

    // Con la prueba, sin plan o caducado: hay que recargar y elegir plan.
    final trial = plan?['is_trial'] == true;
    final notice = trial ? s.trialNotice : (status != 'active' ? s.noPlanNotice : null);
    return widget.compact
        ? _compact(s, plan, tone, label, rows, notice)
        : _wide(s, plan, tone, label, rows, notice);
  }

  void _openPlans(String title) => openFluxerPortal(context, 'plans', title: title);

  Widget _sidebar(
    FluxerStrings s,
    Map<String, dynamic>? plan,
    Color tone,
    String label,
    DateTime? endsAt,
    bool renews,
    double? balance,
    String? email,
  ) {
    final muted = Colors.white.withValues(alpha: 0.6);
    final trial = plan?['is_trial'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // El email bajo el nombre (avatar de 40 + márgenes de la fila del usuario).
        if (email != null && email.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -12),
            child: Padding(
              padding: const EdgeInsets.only(left: 66, right: 12),
              child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 12)),
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    trial ? Icons.hourglass_bottom_rounded : Icons.workspace_premium_outlined,
                    size: 18,
                    color: const Color(0xFFF5C451),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan?['name'] as String? ?? s.noPlan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label, style: TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              if (endsAt != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    renews ? s.renewsOn(endsAt) : s.endsOn(endsAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tone == AppColorScheme.statusAvailable ? muted : tone, fontSize: 12),
                  ),
                ),
              ],
              if (balance != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
                ),
                Row(
                  children: [
                    Expanded(child: Text(s.availableBalance, style: TextStyle(color: muted, fontSize: 12))),
                    Text(
                      s.money(balance),
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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

  Widget _wide(
    FluxerStrings s,
    Map<String, dynamic>? plan,
    Color tone,
    String label,
    List<(IconData, String)> rows,
    String? notice,
  ) {
    final accent = AppColorScheme.accent;
    const bigText = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);
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
          if (notice != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(notice, style: TextStyle(fontSize: 14, height: 1.35, color: AppColorScheme.onSurface))),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Recargar saldo dentro de la app (fluxer_recharge_screen.dart);
          // planes y cuenta, en el portal.
          FilledButton.icon(
            autofocus: widget.autofocus,
            onPressed: () => openFluxerRecharge(context),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 22),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(s.recharge, style: bigText)),
          ),
          const SizedBox(height: 10),
          if (notice != null) ...[
            FilledButton.tonalIcon(
              onPressed: () => _openPlans(s.choosePlan),
              icon: const Icon(Icons.playlist_add_check, size: 22),
              label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(s.choosePlan, style: bigText)),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (notice == null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openPlans(s.changePlan),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(s.changePlan),
                  ),
                ),
                const SizedBox(width: 10),
              ],
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

  Widget _compact(
    FluxerStrings s,
    Map<String, dynamic>? plan,
    Color tone,
    String label,
    List<(IconData, String)> rows,
    String? notice,
  ) {
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
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(notice, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.3, color: AppColorScheme.accent)),
            ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.icon(
                onPressed: () => openFluxerRecharge(context),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: Text(s.recharge),
              ),
              if (notice != null)
                FilledButton.tonalIcon(
                  onPressed: () => _openPlans(s.choosePlan),
                  icon: const Icon(Icons.playlist_add_check, size: 16),
                  label: Text(s.choosePlan),
                )
              else
                TextButton.icon(
                  onPressed: () => _openPlans(s.changePlan),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: Text(s.changePlan),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
