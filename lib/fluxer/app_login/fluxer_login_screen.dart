// FluxerMoon: pantalla "Entrar con Fluxer".
//
// Enseña un código de un solo uso (y su QR). El cliente lo acepta en el
// portal de FluxerHub (/portal/vincular), o pulsa «Entrar con mi cuenta de
// Fluxer» y el navegador abre ese mismo enlace con el código ya puesto.
// Mientras, la app pregunta cada pocos segundos; al aceptarse entra sola.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/navigation/destinations.dart';
import '../../ui/widgets/focus/request_initial_focus.dart';
import '../../ui/widgets/login_scaffold.dart';
import '../../ui/widgets/sign_in_qr_code.dart';
import '../../util/platform_detection.dart';
import '../fluxer_strings.dart';
import 'fluxer_login_service.dart';

enum _Phase { requesting, waiting, connecting, failed }

class FluxerLoginScreen extends StatefulWidget {
  const FluxerLoginScreen({super.key});

  @override
  State<FluxerLoginScreen> createState() => _FluxerLoginScreenState();
}

class _FluxerLoginScreenState extends State<FluxerLoginScreen> {
  final _service = FluxerLoginService();
  final _primaryFocus = FocusNode();

  _Phase _phase = _Phase.requesting;
  FluxerLoginCode? _code;
  Timer? _pollTimer;
  bool _polling = false;
  int _pollFailures = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _primaryFocus.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    _pollTimer?.cancel();
    setState(() {
      _phase = _Phase.requesting;
      _error = null;
      _pollFailures = 0;
    });
    try {
      final code = await _service.start();
      if (!mounted) return;
      setState(() {
        _code = code;
        _phase = _Phase.waiting;
      });
      _pollTimer = Timer.periodic(code.interval, (_) => _poll());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error = FluxerStrings.of(context).hubUnreachable;
      });
    }
  }

  Future<void> _poll() async {
    final code = _code;
    if (code == null || _polling || _phase != _Phase.waiting) return;
    _polling = true;
    try {
      final result = await _service.poll(code.secret);
      if (!mounted) return;
      _pollFailures = 0;
      switch (result.status) {
        case FluxerLoginStatus.pending:
          if (_error != null) setState(() => _error = null);
          if (DateTime.now().isAfter(code.expiresAt)) await _requestCode();
        case FluxerLoginStatus.expired:
          await _requestCode();
        case FluxerLoginStatus.approved:
          _pollTimer?.cancel();
          await _complete(result.session!);
      }
    } catch (_) {
      // Un fallo de red suelto no corta la espera: se reintenta solo.
      if (mounted && ++_pollFailures >= 3) {
        setState(() => _error = FluxerStrings.of(context).stillTrying);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _complete(FluxerLoginSession session) async {
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
    });
    FluxerLoginResult? result;
    try {
      result = await _service.complete(session);
    } catch (_) {
      result = null;
    }
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _phase = _Phase.failed;
        _error = FluxerStrings.of(context).serverUnreachable(
          session.serverName.isEmpty ? session.serverUrl : session.serverName,
        );
      });
      return;
    }
    if (result.switched) {
      context.go(Destinations.home);
    } else {
      context.go('${Destinations.server}?serverId=${result.serverId}');
    }
  }

  void _goBack() {
    if (_phase == _Phase.connecting) return;
    context.go(Destinations.serverSelect);
  }

  Future<void> _openInBrowser() async {
    final code = _code;
    if (code == null) return;
    await launchUrl(Uri.parse(code.approveUrl), mode: LaunchMode.externalApplication);
  }

  /// "K7Q2M9" → "K7Q 2M9": más fácil de leer en una tele.
  static String _pretty(String code) =>
      code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

  /// "https://hub.fluxer.video/portal/vincular?codigo=X" → "hub.fluxer.video/portal/vincular".
  static String _shortUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return '${uri.host}${uri.path}';
  }

  @override
  Widget build(BuildContext context) {
    return SignInBackScope(
      onBack: _goBack,
      child: RequestInitialFocus(
        targetNode: _primaryFocus,
        child: LoginScaffold(
          maxWidth: 760,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Image.asset('assets/images/logo_and_text.png', height: 80),
          ),
          child: _buildCard(context),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final s = FluxerStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.signInWithFluxer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          s.signInWithFluxerSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        _buildBody(context, s),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColorScheme.statusRequested),
          ),
        ],
        const SizedBox(height: 24),
        _buildActions(s),
      ],
    );
  }

  Widget _buildBody(BuildContext context, FluxerStrings s) {
    final code = _code;
    switch (_phase) {
      case _Phase.requesting:
        return _spinner(s.gettingCode);
      case _Phase.connecting:
        return _spinner(s.connecting);
      case _Phase.failed:
        return const SizedBox.shrink();
      case _Phase.waiting:
        if (code == null) return _spinner(s.gettingCode);
        return LayoutBuilder(
          builder: (context, constraints) {
            final steps = _buildSteps(context, s, code);
            final qr = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SignInQrCode(data: code.approveUrl, size: 170),
                const SizedBox(height: 8),
                Text(
                  s.orScan,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [steps, const SizedBox(height: 20), qr],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: steps),
                const SizedBox(width: 24),
                qr,
              ],
            );
          },
        );
    }
  }

  Widget _buildSteps(BuildContext context, FluxerStrings s, FluxerLoginCode code) {
    final muted = AppColorScheme.onSurface.withValues(alpha: 0.75);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _step('1', s.stepOpen, muted),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 2, bottom: 12),
          child: SelectableText(
            _shortUrl(code.approveUrl),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColorScheme.accent,
            ),
          ),
        ),
        _step('2', s.stepCode, muted),
        Padding(
          padding: const EdgeInsets.only(left: 30, top: 6, bottom: 12),
          child: SelectableText(
            _pretty(code.code),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _step('3', s.stepAccept, muted),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(s.waiting, style: TextStyle(fontSize: 13, color: muted)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _step(String number, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            '$number.',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColorScheme.accent),
          ),
        ),
        Expanded(child: Text(text, style: TextStyle(color: color))),
      ],
    );
  }

  Widget _spinner(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildActions(FluxerStrings s) {
    final busy = _phase == _Phase.connecting || _phase == _Phase.requesting;
    final buttons = <Widget>[
      OutlinedButton.icon(
        onPressed: busy ? null : _goBack,
        icon: const Icon(Icons.arrow_back, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.back)),
        style: _buttonStyle(),
      ),
      // En una tele no suele haber navegador: allí, el móvil con el QR.
      if (!PlatformDetection.isTV && _phase == _Phase.waiting)
        OutlinedButton.icon(
          focusNode: _primaryFocus,
          onPressed: _openInBrowser,
          icon: const Icon(Icons.open_in_browser, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.openFluxerAccount)),
          style: _buttonStyle(),
        ),
      if (_phase == _Phase.failed || (PlatformDetection.isTV && _phase == _Phase.waiting))
        OutlinedButton.icon(
          focusNode: _primaryFocus,
          onPressed: _requestCode,
          icon: const Icon(Icons.refresh, size: 18),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text(s.newCode)),
          style: _buttonStyle(),
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  ButtonStyle _buttonStyle() {
    return ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
          return BorderSide(color: AppColorScheme.accent, width: 2);
        }
        return BorderSide(color: AppColorScheme.onSurface.withValues(alpha: 0.2));
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
          return AppColorScheme.accent;
        }
        return AppColorScheme.onSurface.withValues(alpha: 0.8);
      }),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
