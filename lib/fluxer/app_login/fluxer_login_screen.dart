// FluxerPlayer: Pantalla «Entrar con Fluxer»: perfil guardado, código/QR o web.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/repositories/session_repository.dart';
import '../../ui/navigation/app_router.dart';
import '../../ui/navigation/destinations.dart';
import '../../ui/widgets/user_menu_dialog.dart';
import '../../ui/widgets/focus/request_initial_focus.dart';
import '../../ui/widgets/login_scaffold.dart';
import '../../ui/widgets/sign_in_qr_code.dart';
import '../../util/platform_detection.dart';
import '../fluxer_features.dart';
import '../fluxer_strings.dart';
import 'fluxer_login_service.dart';

enum _Phase { requesting, waiting, connecting, failed }

class FluxerLoginScreen extends StatefulWidget {
  const FluxerLoginScreen({super.key, this.relinkUser, this.onBack});

  /// Usuario abierto sin sesión de Fluxer (fluxer_link_gate.dart): hay que
  /// volver a entrar para seguir. Va por encima de la app, fuera de las rutas.
  final String? relinkUser;

  /// «Añadir usuario» desde los perfiles guardados: volver a ellos.
  final VoidCallback? onBack;

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

  bool get _relink => widget.relinkUser != null;

  void _go(String location) {
    if (_relink) {
      appRouter.go(location);
    } else {
      context.go(location);
    }
  }

  void _switchUser() {
    final navigator = appRouter.routerDelegate.navigatorKey.currentContext;
    if (navigator != null && navigator.mounted) showUserMenu(navigator);
  }

  Future<void> _signOut() async {
    _pollTimer?.cancel();
    await GetIt.instance<SessionRepository>().signOutSiloAccount();
    appRouter.go(Destinations.serverSelect);
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
      _go(Destinations.home);
    } else if (FluxerFeatures.fluxerOnly) {
      // Solo Fluxer: no hay pantallas de Moonfin a las que mandar.
      setState(() {
        _phase = _Phase.failed;
        _error = FluxerStrings.of(context).sessionFailed;
      });
    } else {
      _go('${Destinations.server}?serverId=${result.serverId}');
    }
  }

  /// App ya vinculada: sesión de Emby nueva desde FluxerHub, sin contraseña.
  void _goBack() {
    if (_phase == _Phase.connecting) return;
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    // Solo Fluxer: esta es la pantalla de entrada, no hay adónde volver.
    if (FluxerFeatures.fluxerOnly) return;
    context.go(Destinations.serverSelect);
  }

  Future<void> _openInBrowser() async {
    final code = _code;
    if (code == null) return;
    final uri = Uri.parse(code.approveUrl);
    // En Android, primero la pestaña del navegador dentro de la app (Custom
    // Tabs): con algunos móviles abrir el navegador aparte volvía a la app sin
    // hacer nada. Si no hay, el navegador normal.
    var opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? LaunchMode.inAppBrowserView : LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(FluxerStrings.of(context).openLinkFailed)));
    }
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


  // ---------------------------------------------------------------- UI --

  bool get _isTv => PlatformDetection.isTV;
  bool get _isMobile => PlatformDetection.useMobileUi && !_isTv;

  Color get _muted => AppColorScheme.onSurface.withValues(alpha: 0.7);
  Color get _line => AppColorScheme.onSurface.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    return SignInBackScope(
      onBack: _goBack,
      child: RequestInitialFocus(
        targetNode: _primaryFocus,
        child: LoginScaffold(
          maxWidth: _isMobile ? 560 : 860,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Image.asset('assets/images/logo_and_text.png', height: _isMobile ? 56 : 72),
          ),
          child: _buildCard(context),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final s = FluxerStrings.of(context);
    final header = Column(
      children: [
        Text(
          _relink ? s.relinkTitle : s.loginTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: _isMobile ? 22 : 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _relink ? s.relinkSubtitle(widget.relinkUser!) : s.loginSubtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 24),
      ],
    );

    final Widget body = _phase == _Phase.connecting ? _spinner(s.connecting) : _options(s, stacked: _isMobile);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        body,
        if (widget.onBack != null && _phase != _Phase.connecting) ...[
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(s.back),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColorScheme.statusRequested)),
        ],
        if (_phase == _Phase.failed) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              focusNode: _primaryFocus,
              onPressed: _requestCode,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.newCode),
              style: _outlined(),
            ),
          ),
        ],
        if (_relink && _phase != _Phase.connecting) ...[
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _switchUser,
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: Text(s.relinkSwitchUser),
                style: _outlined(),
              ),
              OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, size: 18),
                label: Text(s.relinkSignOut),
                style: _outlined(),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Las dos formas de entrar: «En este aparato» (no en la tele) o «Con tu móvil».
  Widget _options(FluxerStrings s, {required bool stacked}) {
    final code = _code;
    if (_phase == _Phase.requesting || code == null) {
      return _phase == _Phase.failed ? const SizedBox.shrink() : _spinner(s.gettingCode);
    }
    if (_phase == _Phase.failed) return const SizedBox.shrink();

    final withPhone = _optionCard(
      icon: Icons.qr_code_2,
      title: _isTv ? s.optionWithPhoneTv : (_isMobile ? s.optionOtherDevice : s.optionWithPhone),
      child: _codeBlock(s, code),
    );
    if (_isTv) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          withPhone,
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              focusNode: _primaryFocus,
              onPressed: _requestCode,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.newCode),
              style: _outlined(),
            ),
          ),
        ],
      );
    }

    final here = _optionCard(
      icon: Icons.open_in_new,
      title: s.optionThisDevice,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.optionThisDeviceHelp, style: TextStyle(color: _muted, height: 1.35)),
          const SizedBox(height: 16),
          // Verde con brillo, como «Dar acceso a la app» en la web.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
              boxShadow: [
                BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 4)),
              ],
            ),
            child: FilledButton.icon(
              focusNode: _primaryFocus,
              autofocus: true,
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser, size: 22),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(s.openFluxerAccount, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              style: _focusRing().copyWith(
                backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                shadowColor: const WidgetStatePropertyAll(Colors.transparent),
                overlayColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.12)),
                shape: const WidgetStatePropertyAll(StadiumBorder()),
              ),
            ),
          ),
        ],
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [here, _orDivider(s.or), withPhone],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 4, child: here),
        _verticalDivider(s.or),
        Expanded(flex: 6, child: withPhone),
      ],
    );
  }

  Widget _optionCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(_isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: AppColorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColorScheme.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // Pasos con el enlace y el código, una raya, y el QR («o escanea con la
  // cámara»): queda claro que es lo uno o lo otro. En el móvil el QR va
  // pequeño (no se puede escanear la propia pantalla): lo importante es el
  // código. El enlace se abre al pulsarlo y el código se copia (no en la tele).
  Widget _codeBlock(FluxerStrings s, FluxerLoginCode code) {
    final qrSize = _isMobile ? 120.0 : (_isTv ? 200.0 : 170.0);
    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignInQrCode(data: code.approveUrl, size: qrSize),
        const SizedBox(height: 8),
        Text(s.scanQr, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: _muted, fontWeight: FontWeight.w600)),
      ],
    );
    final linkStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColorScheme.accent);
    final codeBox = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _pretty(code.code),
            style: TextStyle(
              fontSize: _isMobile ? 30 : 38,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!_isTv) ...[
            const SizedBox(width: 10),
            Icon(Icons.copy_rounded, size: 20, color: _muted),
          ],
        ],
      ),
    );
    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _step('1', s.stepOpen),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2, bottom: 12),
          child: _isTv
              ? Text(_shortUrl(code.approveUrl), style: linkStyle)
              : InkWell(
                  onTap: _openInBrowser,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _shortUrl(code.approveUrl),
                            style: linkStyle.copyWith(decoration: TextDecoration.underline, decorationColor: AppColorScheme.accent),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.open_in_new, size: 16, color: AppColorScheme.accent),
                      ],
                    ),
                  ),
                ),
        ),
        _step('2', s.stepCode),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 6, bottom: 12),
          child: _isTv
              ? codeBox
              : Tooltip(
                  message: s.tapToCopy,
                  child: InkWell(
                    onTap: () => _copyCode(s, code.code),
                    borderRadius: BorderRadius.circular(12),
                    child: codeBox,
                  ),
                ),
        ),
        _step('3', s.stepAccept),
        const SizedBox(height: 14),
        Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Flexible(child: Text(s.waiting, style: TextStyle(fontSize: 13, color: _muted))),
          ],
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              steps,
              Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Divider(color: _line)),
              Center(child: qr),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: steps),
            Container(width: 1, height: qrSize, margin: const EdgeInsets.symmetric(horizontal: 22), color: _line),
            qr,
          ],
        );
      },
    );
  }

  Future<void> _copyCode(FluxerStrings s, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(s.codeCopied), duration: const Duration(seconds: 2)),
    );
  }

  Widget _step(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(right: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColorScheme.accent, shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        Expanded(child: Text(text, style: TextStyle(color: _muted))),
      ],
    );
  }

  Widget _orDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: _line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Divider(color: _line)),
        ],
      ),
    );
  }

  Widget _verticalDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      // Altura fija: un IntrinsicHeight no admite el LayoutBuilder de dentro.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 90, child: VerticalDivider(color: _line, width: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(label, style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          SizedBox(height: 90, child: VerticalDivider(color: _line, width: 1)),
        ],
      ),
    );
  }

  Widget _spinner(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label),
        ],
      ),
    );
  }

  /// Borde blanco al tener el foco (mando de la tele, teclado).
  ButtonStyle _focusRing({bool filled = false}) => ButtonStyle(
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.focused) ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
    ),
  );

  ButtonStyle _outlined() {
    return ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
          return BorderSide(color: AppColorScheme.accent, width: 2);
        }
        return BorderSide(color: AppColorScheme.onSurface.withValues(alpha: 0.25));
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
          return AppColorScheme.accent;
        }
        return AppColorScheme.onSurface.withValues(alpha: 0.85);
      }),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
    );
  }
}
