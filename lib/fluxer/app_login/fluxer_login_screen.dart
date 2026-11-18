// FluxerPlayer: pantalla "Entrar con Fluxer".
//
// - Con una cuenta ya vinculada: su perfil (foto o inicial, nombre) con
//   «Continuar como …» (sesión nueva desde FluxerHub, sin contraseña) y
//   «Cambiar de cuenta» (la desvincula). En tele y ordenador, a la izquierda;
//   en el móvil, arriba.
// - Las formas de entrar, separadas como DOS opciones (una u otra):
//   · «En este aparato»: abre la web de Fluxer con el código ya puesto
//     (ordenador y móvil; nunca en la tele, que no tiene navegador).
//   · «Con tu móvil»: QR + código de un solo uso que se acepta en
//     hub.fluxer.video/portal/vincular (en la tele, la única opción).
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
import '../fluxer_features.dart';
import '../fluxer_strings.dart';
import '../hub/fluxer_hub_client.dart';
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

  /// La app ya está vinculada a una cuenta de Fluxer: se ofrece seguir con
  /// ella de un toque (sin código).
  bool _linked = false;
  String? _profileName;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _requestCode();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!await FluxerHubClient.instance.isLinked) return;
    if (mounted) setState(() => _linked = true);
    final me = await FluxerHubClient.instance.me();
    final customer = (me?['customer'] as Map?)?.cast<String, dynamic>();
    if (!mounted || customer == null) return;
    setState(() {
      _profileName = (customer['name'] as String?)?.trim();
      _avatarUrl = customer['avatar_url'] as String?;
    });
  }

  /// «Cambiar de cuenta»: desvincula la guardada y deja solo las formas de entrar.
  Future<void> _switchAccount() async {
    await FluxerHubClient.instance.logout();
    if (mounted) {
      setState(() {
        _linked = false;
        _profileName = null;
        _avatarUrl = null;
      });
    }
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
    } else if (FluxerFeatures.fluxerOnly) {
      // Solo Fluxer: no hay pantallas de Moonfin a las que mandar.
      setState(() {
        _phase = _Phase.failed;
        _error = FluxerStrings.of(context).sessionFailed;
      });
    } else {
      context.go('${Destinations.server}?serverId=${result.serverId}');
    }
  }

  /// App ya vinculada: sesión de Emby nueva desde FluxerHub, sin contraseña.
  Future<void> _continueWithHub() async {
    _pollTimer?.cancel();
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
    });
    final session = await _service.sessionFromHub();
    if (!mounted) return;
    if (session == null) {
      setState(() => _linked = false);
      await _requestCode();
      if (mounted) setState(() => _error = FluxerStrings.of(context).hubSessionFailed);
      return;
    }
    await _complete(session);
  }

  void _goBack() {
    if (_phase == _Phase.connecting) return;
    // Solo Fluxer: esta es la pantalla de entrada, no hay adónde volver.
    if (FluxerFeatures.fluxerOnly) return;
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


  // ---------------------------------------------------------------- UI --

  bool get _isTv => PlatformDetection.isTV;
  bool get _isMobile => PlatformDetection.useMobileUi && !_isTv;
  bool get _showProfile => _linked && _phase != _Phase.connecting;

  Color get _muted => AppColorScheme.onSurface.withValues(alpha: 0.7);
  Color get _line => AppColorScheme.onSurface.withValues(alpha: 0.14);

  @override
  Widget build(BuildContext context) {
    final wide = !_isMobile && _showProfile;
    return SignInBackScope(
      onBack: _goBack,
      child: RequestInitialFocus(
        targetNode: _primaryFocus,
        child: LoginScaffold(
          maxWidth: wide ? 1080 : (_isMobile ? 560 : 860),
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
          s.loginTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: _isMobile ? 22 : 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(s.loginSubtitle, textAlign: TextAlign.center, style: TextStyle(color: _muted)),
        const SizedBox(height: 24),
      ],
    );

    final Widget body;
    if (_phase == _Phase.connecting) {
      body = _spinner(s.connecting);
    } else if (!_showProfile) {
      body = _options(s, stacked: _isMobile);
    } else if (_isMobile) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _profile(s),
          _orDivider(s.orOtherWay),
          _options(s, stacked: true),
        ],
      );
    } else {
      // Tele y ordenador: perfil a la izquierda, otra cuenta a la derecha.
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 4, child: _profile(s)),
          _verticalDivider(s.or),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.otherAccount, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _options(s, stacked: true),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        body,
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColorScheme.statusRequested)),
        ],
        if (_phase == _Phase.failed) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              focusNode: _showProfile ? null : _primaryFocus,
              onPressed: _requestCode,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(s.newCode),
              style: _outlined(),
            ),
          ),
        ],
      ],
    );
  }

  // Perfil de la cuenta de Fluxer guardada.
  Widget _profile(FluxerStrings s) {
    final name = (_profileName?.isNotEmpty ?? false) ? _profileName! : s.fluxerAccount;
    final first = name.split(' ').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final size = _isMobile ? 72.0 : 104.0;
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColorScheme.accent, width: 3),
        gradient: const LinearGradient(colors: [Color(0xFF00A4DC), Color(0xFF0057D9)]),
      ),
      clipBehavior: Clip.antiAlias,
      child: _avatarUrl == null
          ? Center(child: Text(initial, style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.bold, color: Colors.white)))
          : Image.network(
              _avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(initial, style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
    );

    return Container(
      padding: EdgeInsets.all(_isMobile ? 18 : 28),
      decoration: BoxDecoration(
        color: AppColorScheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColorScheme.accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: avatar),
          const SizedBox(height: 14),
          Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: _isMobile ? 20 : 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 16, color: _muted),
              const SizedBox(width: 6),
              Text(s.fluxerAccountLabel, style: TextStyle(color: _muted)),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            focusNode: _primaryFocus,
            autofocus: true,
            onPressed: _continueWithHub,
            icon: const Icon(Icons.login),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(s.continueAs(first), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            style: _focusRing(filled: true),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _switchAccount,
            icon: const Icon(Icons.manage_accounts_outlined, size: 18),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(s.switchAccount)),
            style: _outlined(),
          ),
        ],
      ),
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
              focusNode: _showProfile ? null : _primaryFocus,
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
          FilledButton.icon(
            focusNode: _showProfile ? null : _primaryFocus,
            autofocus: !_showProfile,
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.openFluxerAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            style: _focusRing(filled: true),
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

  // QR + pasos con el código. En el móvil el QR va pequeño (no se puede
  // escanear la propia pantalla): lo importante es el código.
  Widget _codeBlock(FluxerStrings s, FluxerLoginCode code) {
    final qrSize = _isMobile ? 120.0 : (_isTv ? 200.0 : 170.0);
    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SignInQrCode(data: code.approveUrl, size: qrSize),
        const SizedBox(height: 8),
        Text(s.scanQr, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _muted)),
      ],
    );
    final steps = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _step('1', s.stepOpen),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2, bottom: 12),
          child: SelectableText(
            _shortUrl(code.approveUrl),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColorScheme.accent),
          ),
        ),
        _step('2', s.stepCode),
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 6, bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColorScheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: SelectableText(
              _pretty(code.code),
              style: TextStyle(
                fontSize: _isMobile ? 30 : 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [steps, const SizedBox(height: 16), Center(child: qr)]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [qr, const SizedBox(width: 24), Expanded(child: steps)],
        );
      },
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
