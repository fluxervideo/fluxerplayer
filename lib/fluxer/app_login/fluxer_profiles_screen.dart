// FluxerPlayer: Entrada sin sesión: los usuarios guardados en el aparato o, si
// no hay ninguno, la pantalla de código/QR.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_preference/jellyfin_preference.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../auth/models/server.dart';
import '../../auth/models/user.dart';
import '../../auth/repositories/server_repository.dart';
import '../../auth/repositories/session_repository.dart';
import '../../auth/store/authentication_store.dart';
import '../../data/services/pin_guard.dart';
import '../../data/services/server_pin_service.dart';
import '../../ui/navigation/destinations.dart';
import '../../ui/widgets/login_scaffold.dart';
import '../../ui/widgets/pin_entry_dialog.dart';
import '../../ui/widgets/profile_carousel.dart';
import '../../util/platform_detection.dart';
import '../fluxer_routes.dart';
import '../fluxer_strings.dart';
import '../hub/fluxer_hub_client.dart';
import '../hub/fluxer_servers.dart';
import '../hub/fluxer_subscription_card.dart';
import 'fluxer_login_screen.dart';
import 'fluxer_login_service.dart';

class _Account {
  const _Account(this.server, this.user);

  final Server server;
  final PrivateUser user;
}

class FluxerStartScreen extends StatefulWidget {
  const FluxerStartScreen({super.key, this.adding = false});

  /// «Añadir usuario»: la pantalla de código aunque haya usuarios guardados.
  final bool adding;

  @override
  State<FluxerStartScreen> createState() => _FluxerStartScreenState();
}

class _FluxerStartScreenState extends State<FluxerStartScreen> {
  static const _danger = Color(0xFFC62828);

  final _serverRepo = GetIt.instance<ServerRepository>();
  final _authStore = GetIt.instance<AuthenticationStore>();
  final _session = GetIt.instance<SessionRepository>();
  final _carouselFocus = FocusNode();

  List<_Account>? _accounts;
  int _selected = 0;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(FluxerStartScreen old) {
    super.didUpdateWidget(old);
    if (old.adding && !widget.adding) _load();
  }

  @override
  void dispose() {
    _carouselFocus.dispose();
    super.dispose();
  }

  /// Los usuarios de Fluxer guardados. El que no tiene su token del hub no ha
  /// entrado con Fluxer: se borra del aparato.
  Future<void> _load() async {
    await _serverRepo.loadStoredServers();
    final candidates = <_Account>[];
    for (final server in _serverRepo.servers) {
      if (!FluxerServers.contains(server.id)) continue;
      for (final user in _authStore.getUsers(server.id)) {
        if (FluxerServers.hasUsers && !FluxerServers.isFluxerUser(server.id, user.id)) continue;
        candidates.add(_Account(server, user));
      }
    }
    // Versión antigua sin lista de usuarios: si solo hay uno, el token es suyo.
    if (!FluxerServers.hasUsers && candidates.length == 1) {
      await FluxerServers.addUser(candidates.first.server.id, candidates.first.user.id);
    }

    final hub = FluxerHubClient.instance;
    final valid = <_Account>[];
    for (final account in candidates) {
      if (await hub.hasToken(serverId: account.server.id, userId: account.user.id) || hub.storageUnavailable) {
        valid.add(account);
      } else {
        await _forget(account);
      }
    }
    valid.sort((a, b) => b.user.lastUsed.compareTo(a.user.lastUsed));

    if (!mounted) return;
    setState(() {
      _accounts = valid;
      _selected = _selected.clamp(0, valid.isEmpty ? 0 : valid.length - 1);
    });
    if (valid.isNotEmpty && !PlatformDetection.useMobileUi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _carouselFocus.requestFocus();
      });
    }
  }

  /// Borra el usuario del aparato y cierra su sesión de Emby.
  Future<void> _forget(_Account account) async {
    final token = account.user.accessToken;
    if (token.isNotEmpty) {
      try {
        await Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)))
            .post<dynamic>('${account.server.address}/Sessions/Logout', options: Options(headers: {'X-Emby-Token': token}));
      } catch (_) {}
    }
    await _authStore.removeUser(account.server.id, account.user.id);
    await FluxerServers.removeUser(account.server.id, account.user.id);
  }

  String? _avatarUrl(_Account account) {
    final token = account.user.accessToken;
    if (token.isEmpty) return null;
    final base =
        '${account.server.address}/Users/${account.user.id}/Images/Primary?quality=90&maxHeight=180&${account.server.serverType.tokenQueryParam}=$token';
    final tag = account.user.imageTag;
    return tag == null || tag.isEmpty ? base : '$base&tag=$tag';
  }

  ProfileEntry _entry(_Account account) => ProfileEntry(
        id: account.user.id,
        name: account.user.name,
        avatarUrl: _avatarUrl(account),
      );

  Widget _subtitle(_Account account) => ProfileStatusLine(
        '${account.server.name} · ${account.server.serverType.productName}',
      );

  Future<void> _enter(_Account account) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _enterVerified(account);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterVerified(_Account account) async {
    final guard = PinGuard.forAccount(
      store: GetIt.instance<PreferenceStore>(),
      service: GetIt.instance<ServerPinService>(),
      userId: account.user.id,
      server: account.server,
      accessToken: account.user.accessToken,
    );
    await guard.refresh();
    if (!mounted) return;
    if (guard.pin.isPinEnabled) {
      final verified = await PinEntryDialog.show(context, mode: PinEntryMode.verify, onVerifyAsync: guard.verify);
      if (!verified || !mounted) return;
    }

    final router = GoRouter.of(context);
    if (await _session.switchCurrentSession(serverId: account.server.id, userId: account.user.id)) {
      router.go('${Destinations.startup}?bootstrap=1');
      return;
    }

    // La sesión de Emby ya no vale: una nueva desde el hub, sin código.
    final service = FluxerLoginService();
    FluxerLoginResult? result;
    try {
      final session = await service.sessionFromHub(serverId: account.server.id, userId: account.user.id);
      if (session != null) result = await service.complete(session);
    } catch (_) {}
    if (!mounted) return;
    if (result != null && result.switched) {
      router.go(Destinations.home);
      return;
    }
    final s = FluxerStrings.of(context);
    final hub = FluxerHubClient.instance;
    if (!hub.storageUnavailable && !await hub.hasToken(serverId: account.server.id, userId: account.user.id)) {
      // El hub lo ha desvinculado: ya no cuenta como logueado.
      await _forget(account);
      await _load();
      if (mounted) setState(() => _error = s.hubSessionFailed);
      return;
    }
    setState(() => _error = s.sessionFailed);
  }

  Future<void> _remove(_Account account) async {
    final s = FluxerStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.removeUser),
        content: Text(s.removeUserConfirm(account.user.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    await FluxerHubClient.instance.logoutUser(serverId: account.server.id, userId: account.user.id);
    await _forget(account);
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  void _addUser() => context.go('$fluxerLoginPath?add=1');

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    if (widget.adding) {
      return FluxerLoginScreen(
        onBack: (accounts?.isNotEmpty ?? true) ? () => context.go(fluxerLoginPath) : null,
      );
    }
    if (accounts == null) {
      return Scaffold(
        backgroundColor: AppColorScheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (accounts.isEmpty) return const FluxerLoginScreen();

    return SignInBackScope(
      onBack: () {},
      child: Scaffold(
        backgroundColor: AppColorScheme.background,
        body: SafeArea(
          child: PlatformDetection.useMobileUi ? _buildMobile(context, accounts) : _buildWide(context, accounts),
        ),
      ),
    );
  }

  Widget _title(FluxerStrings s, {required double size}) => Row(
        children: [
          Image.asset('assets/images/logo_and_text.png', height: size * 1.6),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              s.whoIsWatching,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: AppColorScheme.onSurface),
            ),
          ),
        ],
      );

  Widget _errorText() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: AppColorScheme.statusRequested)),
      );

  List<Widget> _actions(FluxerStrings s, _Account selected, {required bool withAdd}) => [
        if (withAdd)
          OutlinedButton.icon(
            onPressed: _busy ? null : _addUser,
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
            label: Text(s.addUser),
            style: _outlined(),
          ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _remove(selected),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: Text(s.removeUser),
          style: _outlined(danger: true),
        ),
      ];

  Widget _buildWide(BuildContext context, List<_Account> accounts) {
    final s = FluxerStrings.of(context);
    final selected = accounts[_selected];
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 28, 48, 32),
      child: Column(
        children: [
          _title(s, size: 24),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ProfileCarousel(
                        entries: [for (final a in accounts) _entry(a)],
                        selected: _selected,
                        focusNode: _carouselFocus,
                        onSelected: (index) => setState(() => _selected = index),
                        onActivate: (index) => _enter(accounts[index]),
                        subtitle: _busy
                            ? const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : _subtitle(selected),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // Hueco fijo (380, el ancho de la tarjeta): mientras carga la
                // del perfil elegido, los perfiles no se mueven.
                SizedBox(
                  width: 380,
                  child: Center(
                    child: SingleChildScrollView(
                      child: FluxerSubscriptionCard(
                        key: ValueKey('${selected.server.id}:${selected.user.id}'),
                        serverId: selected.server.id,
                        userId: selected.user.id,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) _errorText(),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _actions(s, selected, withAdd: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context, List<_Account> accounts) {
    final s = FluxerStrings.of(context);
    final selected = accounts[_selected];
    final entries = [for (final a in accounts) _entry(a)];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          _title(s, size: 20),
          const SizedBox(height: 24),
          ProfileHero(
            entry: entries[_selected],
            subtitle: _subtitle(selected),
            onPrevious: _selected > 0 ? () => setState(() => _selected--) : null,
            onNext: _selected < accounts.length - 1 ? () => setState(() => _selected++) : null,
          ),
          FluxerSubscriptionCard(
            key: ValueKey('${selected.server.id}:${selected.user.id}'),
            compact: true,
            serverId: selected.server.id,
            userId: selected.user.id,
          ),
          const SizedBox(height: 24),
          ProfileStrip(
            entries: entries,
            selected: _selected,
            onSelected: (index) => setState(() => _selected = index),
            onAdd: _busy ? null : _addUser,
            addLabel: s.addUser,
          ),
          const SizedBox(height: 20),
          ProfilePrimaryButton(
            label: s.enterAs(selected.user.name),
            onPressed: _busy ? null : () => _enter(selected),
          ),
          if (_error != null) _errorText(),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: _actions(s, selected, withAdd: false),
          ),
        ],
      ),
    );
  }

  ButtonStyle _outlined({bool danger = false}) {
    final strong = danger ? _danger : AppColorScheme.accent;
    return ButtonStyle(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) {
          return BorderSide(color: strong, width: 2);
        }
        return BorderSide(color: (danger ? _danger : AppColorScheme.onSurface).withValues(alpha: danger ? 0.6 : 0.25));
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (danger) return const Color(0xFFEF5350);
        if (states.contains(WidgetState.focused) || states.contains(WidgetState.hovered)) return strong;
        return AppColorScheme.onSurface.withValues(alpha: 0.85);
      }),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
    );
  }
}
