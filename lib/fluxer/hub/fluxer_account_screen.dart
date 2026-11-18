// FluxerPlayer: Ajustes → «Mi cuenta Fluxer».
//
// - Plan (estado, caducidad, renovación automática) y saldo, con «Renovar».
//   En el ordenador o el móvil abre los planes en el navegador; en la tele
//   (sin navegador) enseña un QR para hacerlo desde el móvil.
// - Estado del servidor.
// - «Invita y gana»: el enlace de referidos, con QR y botón de copiar.
// - Diagnóstico: activar la grabación y mandarlo a Fluxer (llega como una
//   solicitud con el registro adjunto).
// Sin vincular (entró sin «Entrar con Fluxer»), explica cómo vincularla.
//
// Enganche: lib/ui/screens/settings/settings_side_panel.dart (`// FLUXER:`).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../data/services/log_service.dart';
import '../../preference/user_preferences.dart';
import '../../ui/screens/settings/settings_app_bar.dart';
import '../../ui/widgets/sign_in_qr_code.dart';
import '../../util/platform_detection.dart';
import '../fluxer_routes.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';

class FluxerAccountScreen extends StatefulWidget {
  const FluxerAccountScreen({super.key});

  @override
  State<FluxerAccountScreen> createState() => _FluxerAccountScreenState();
}

class _FluxerAccountScreenState extends State<FluxerAccountScreen> {
  final _client = FluxerHubClient.instance;
  final _prefs = GetIt.instance<UserPreferences>();

  bool _loading = true;
  bool _linked = false;
  Map<String, dynamic>? _me;
  bool _sendingDiagnostic = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final me = await _client.isLinked ? await _client.me() : null;
    // me() borra el token si el Hub dice que ya no está vinculada; sin
    // conexión lo deja (sigue vinculada, solo que sin datos ahora mismo).
    final linked = await _client.isLinked;
    if (!mounted) return;
    setState(() {
      _linked = linked;
      _me = me;
      _loading = false;
    });
  }

  Map<String, dynamic>? _map(String key) => (_me?[key] as Map?)?.cast<String, dynamic>();

  /// QR para abrir [url] en el móvil (el enlace de invitación en la tele).
  Future<void> _open(String url, String title) async {
    final s = FluxerStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.scanWithPhone, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SignInQrCode(data: url, size: 220),
            const SizedBox(height: 12),
            SelectableText(
              Uri.parse(url).host + Uri.parse(url).path,
              style: TextStyle(color: AppColorScheme.accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: Text(s.gotIt)),
        ],
      ),
    );
  }

  Future<void> _sendDiagnostic() async {
    final s = FluxerStrings.of(context);
    final comment = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.sendDiagnostic),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.sendDiagnosticHelp),
              const SizedBox(height: 12),
              TextField(
                controller: comment,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(labelText: s.reportCommentHint, border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.back)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.send)),
        ],
      ),
    );
    final text = comment.text.trim();
    comment.dispose();
    if (send != true || !mounted) return;

    setState(() => _sendingDiagnostic = true);
    String message;
    try {
      final id = await _client.diagnostics(
        GetIt.instance<LogService>().exportText(maxEntries: 5000),
        comment: text.isEmpty ? null : text,
      );
      message = id == null ? s.reportNeedsFluxerLogin : s.reportSent;
    } catch (_) {
      message = s.reportFailed;
    }
    if (!mounted) return;
    setState(() => _sendingDiagnostic = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    return Scaffold(
      appBar: buildSettingsAppBar(context, Text(s.fluxerAccount)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _linked ? _linkedTiles(s) : _unlinkedTiles(s),
            ),
    );
  }

  List<Widget> _unlinkedTiles(FluxerStrings s) => [
    Padding(
      padding: const EdgeInsets.all(16),
      child: Text(s.fluxerAccountUnlinked),
    ),
    ListTile(
      autofocus: true,
      leading: const Icon(Icons.qr_code_2),
      title: Text(s.signInWithFluxer),
      subtitle: Text(s.signInWithFluxerSubtitle),
      onTap: () => context.go(fluxerLoginPath),
    ),
    ..._diagnosticTiles(s, linked: false),
  ];

  List<Widget> _linkedTiles(FluxerStrings s) {
    final plan = _map('plan');
    final server = _map('server');
    final customer = _map('customer');
    final referral = _map('referral');
    final urls = _map('urls') ?? const {};
    final plansUrl = urls['plans'] as String?;
    final endsAt = DateTime.tryParse(plan?['ends_at'] as String? ?? '')?.toLocal();
    final balance = (customer?['balance'] as num?)?.toDouble();

    return [
      _header(s.fluxerPlanSection),
      ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(plan?['name'] as String? ?? s.noPlan),
        subtitle: Text([
          if (plan?['status_label'] != null) plan!['status_label'] as String,
          // El estado activo ya dice la fecha («próxima renovación …»).
          if (endsAt != null && plan?['status'] != 'active') s.planEndsOn(endsAt),
          if (plan?['auto_renew'] == true) s.autoRenewOn,
          if (balance != null) s.balance(balance),
        ].join(' · ')),
      ),
      if (plansUrl != null)
        ListTile(
          autofocus: true,
          leading: const Icon(Icons.autorenew),
          title: Text(s.renew),
          subtitle: Text(PlatformDetection.isTV ? s.renewOnPhone : s.renewInBrowserSignedIn),
          // Portal ya con la sesión iniciada: navegador, o QR en la tele.
          onTap: () => openFluxerPortal(context, 'plans', title: s.renew),
        ),
      if (server != null)
        ListTile(
          leading: Icon(
            server['status'] == 'operational' ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: server['status'] == 'operational' ? AppColorScheme.statusAvailable : AppColorScheme.statusRequested,
          ),
          title: Text(server['name'] as String? ?? ''),
          subtitle: Text(server['status_label'] as String? ?? ''),
        ),
      if (referral != null) ...[
        _header(s.inviteSection),
        // Solo el código; al pulsar se copia el enlace (en la tele, donde
        // copiar no sirve, se enseña su QR).
        ListTile(
          leading: const Icon(Icons.card_giftcard),
          title: Text(s.inviteCode(_inviteCode(referral['share_url'] as String))),
          subtitle: Text(
            '${s.inviteHelp(referral['reward_amount'] as num?)} '
            '${PlatformDetection.isTV ? s.inviteTapForQr : s.inviteTapToCopy}',
          ),
          onTap: () async {
            final url = referral['share_url'] as String;
            if (PlatformDetection.isTV) {
              await _open(url, s.inviteTitle);
              return;
            }
            await Clipboard.setData(ClipboardData(text: url));
            if (mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.inviteCopied)));
            }
          },
        ),
      ],
      ..._diagnosticTiles(s, linked: true),
      // «Cerrar sesión» está en el menú del usuario (la foto) y ya desvincula
      // la app de FluxerHub: aquí no hace falta un botón igual.
    ];
  }

  List<Widget> _diagnosticTiles(FluxerStrings s, {required bool linked}) => [
    _header(s.diagnosticSection),
    ListenableBuilder(
      listenable: _prefs,
      builder: (context, _) => SwitchListTile(
        secondary: const Icon(Icons.troubleshoot),
        title: Text(s.recordDiagnostic),
        subtitle: Text(s.recordDiagnosticHelp),
        value: _prefs.get(UserPreferences.diagnosticLoggingEnabled),
        onChanged: (v) => _prefs.set(UserPreferences.diagnosticLoggingEnabled, v),
      ),
    ),
    if (linked)
      ListTile(
        enabled: !_sendingDiagnostic,
        leading: _sendingDiagnostic
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        title: Text(s.sendDiagnostic),
        subtitle: Text(s.sendDiagnosticSubtitle),
        onTap: _sendDiagnostic,
      ),
  ];

  /// «https://www.fluxer.video/r/RMDSDWYR» → «RMDSDWYR».
  static String _inviteCode(String url) {
    final segments = Uri.tryParse(url)?.pathSegments.where((p) => p.isNotEmpty).toList() ?? const [];
    return segments.isEmpty ? url : segments.last;
  }

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.bold, color: AppColorScheme.accent),
    ),
  );
}
