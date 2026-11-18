// FluxerPlayer: avisos de FluxerHub en la app.
//
// Al arrancar (con unos segundos de margen) y cada 30 minutos, si la app
// está vinculada al Hub (entró con «Entrar con Fluxer») y hay sesión, pide
// /api/app/me y enseña, con la tarjeta grande (showFluxerCard), uno detrás de
// otro:
// - Una incidencia en su servidor: una vez cada 6 horas mientras dure.
// - El plan: si no está activo (caducado, suspendido…) o caduca en
//   [_warnDays] días o menos y no se va a renovar solo. Como mucho una vez al
//   día, con «Renovar» (abre los planes en el portal).
// - Mantenimientos programados de su servidor: una vez cada uno.
// - Avisos globales que el Hub marca para enseñar en ventana y que el cliente
//   no ha cerrado aún («Entendido» lo marca también en el portal).
//
// Enganche: lib/app.dart (`// FLUXER:`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/repositories/session_repository.dart';
import '../../ui/navigation/app_router.dart';
import '../fluxer_strings.dart';
import '../server_message/fluxer_server_message.dart';
import '../home/fluxer_home_layout.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';

class FluxerHubWatcher {
  FluxerHubWatcher._();

  static const _interval = Duration(minutes: 30);
  static const _warnDays = 5;
  static const _planWarnedKey = 'fluxer_plan_warned_day';
  static const _seenMaintenancesKey = 'fluxer_seen_maintenances';
  static const _incidentWarnedKey = 'fluxer_incident_warned_at';
  static const _incidentEvery = Duration(hours: 6);

  static Timer? _timer;
  static bool _running = false;

  /// Arranca la vigilancia (una sola vez).
  static void start() {
    if (_timer != null) return;
    Timer(const Duration(seconds: 8), check);
    _timer = Timer.periodic(_interval, (_) => check());
  }

  /// Consulta el Hub y enseña lo que toque. No hace nada sin sesión.
  static Future<void> check() async {
    if (_running) return;
    _running = true;
    try {
      if (GetIt.instance<SessionRepository>().activeUserId == null) return;
      // Las filas de inicio que manda Emby (no necesita el Hub).
      await FluxerHomeLayout.refresh();
      if (!await FluxerHubClient.instance.isLinked) return;
      final me = await FluxerHubClient.instance.me();
      if (me == null) return;

      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final s = FluxerStrings.of(context);
      final prefs = await SharedPreferences.getInstance();
      final urls = (me['urls'] as Map?)?.cast<String, dynamic>() ?? const {};

      await _incident(s, prefs, (me['server'] as Map?)?.cast<String, dynamic>());
      await _plan(s, prefs, (me['plan'] as Map?)?.cast<String, dynamic>(), urls['plans'] as String?);
      await _notices(s, prefs, (me['notices'] as List?) ?? const []);
    } catch (_) {
      // Un fallo del Hub nunca debe molestar al cliente: se reintenta luego.
    } finally {
      _running = false;
    }
  }

  /// Incidencia en su servidor (FluxerHub la marca al fallar la conexión):
  /// una vez cada [_incidentEvery] mientras dure.
  static Future<void> _incident(FluxerStrings s, SharedPreferences prefs, Map<String, dynamic>? server) async {
    if (server == null || server['status'] != 'incident') return;
    final last = prefs.getInt(_incidentWarnedKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _incidentEvery.inMilliseconds) return;
    await prefs.setInt(_incidentWarnedKey, now);
    await showFluxerCard(
      title: s.serverIncidentTitle,
      text: s.serverIncident(server['name'] as String? ?? 'tu servidor'),
      icon: Icons.warning_amber_rounded,
    );
  }

  static Future<void> _plan(
    FluxerStrings s,
    SharedPreferences prefs,
    Map<String, dynamic>? plan,
    String? plansUrl,
  ) async {
    if (plan == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (prefs.getString(_planWarnedKey) == today) return;

    final status = plan['status'] as String? ?? '';
    final endsAt = DateTime.tryParse(plan['ends_at'] as String? ?? '')?.toLocal();
    final renewsAlone = (plan['auto_renew'] as bool? ?? false) &&
        (plan['balance_covers_next_renewal'] as bool? ?? false);

    String? text;
    if (status != 'active') {
      text = s.planNotActive(plan['status_label'] as String? ?? status);
    } else if (endsAt != null && !renewsAlone) {
      final days = endsAt.difference(DateTime.now()).inHours / 24;
      if (days <= _warnDays) text = s.planEndsSoon(endsAt, days.ceil());
    }
    if (text == null) return;

    await prefs.setString(_planWarnedKey, today);
    final renew = await showFluxerCard(
      title: s.planTitle,
      text: text,
      actionLabel: plansUrl == null ? null : s.renew,
      icon: Icons.event_busy_outlined,
    );
    if (renew == true) {
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // Portal ya con la sesión iniciada: navegador, o QR en la tele.
        await openFluxerPortal(context, 'plans', title: s.renew);
      }
    }
  }

  static Future<void> _notices(FluxerStrings s, SharedPreferences prefs, List<dynamic> notices) async {
    final seen = prefs.getStringList(_seenMaintenancesKey) ?? <String>[];
    for (final raw in notices) {
      if (raw is! Map) continue;
      final notice = raw.cast<String, dynamic>();
      final id = notice['id'];
      final title = notice['title'] as String? ?? '';
      final body = (notice['body'] as String? ?? '').trim();

      if (notice['kind'] == 'maintenance') {
        final key = '$id';
        if (seen.contains(key)) continue;
        seen.add(key);
        await prefs.setStringList(_seenMaintenancesKey, seen.length > 50 ? seen.sublist(seen.length - 50) : seen);
        await showFluxerCard(title: title, text: body.isEmpty ? title : body, icon: Icons.build_outlined);
        continue;
      }

      // Aviso global: solo los de ventana que aún no ha cerrado.
      if (notice['modal'] != true || notice['acknowledged'] == true || id is! int) continue;
      await showFluxerCard(title: title, text: body.isEmpty ? title : body);
      await FluxerHubClient.instance.acknowledgeNotice(id);
    }
  }
}
