// FluxerPlayer: Ajustes → «Mi cuenta Fluxer» en tele y ordenador: el panel de
// la derecha (donde las demás categorías tienen la vista previa) con la
// suscripción, o «Entrar con Fluxer» si la app no está vinculada.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../fluxer_routes.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_subscription_card.dart';

class FluxerSettingsPane extends StatefulWidget {
  const FluxerSettingsPane({super.key});

  @override
  State<FluxerSettingsPane> createState() => _FluxerSettingsPaneState();
}

class _FluxerSettingsPaneState extends State<FluxerSettingsPane> {
  final _client = FluxerHubClient.instance;
  bool? _linked;

  @override
  void initState() {
    super.initState();
    _client.linkChanges.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    _client.linkChanges.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    final linked = await _client.isLinked;
    if (mounted && linked != _linked) setState(() => _linked = linked);
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final linked = _linked;
    final Widget content;
    if (linked == null) {
      content = const CircularProgressIndicator();
    } else if (linked) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FluxerSubscriptionCard(fill: true),
        ),
      );
    } else {
      content = SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/app_icon.png', width: 56, height: 56),
              const SizedBox(height: 16),
              Text(s.fluxerAccountUnlinked, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('$fluxerLoginPath?add=1'),
                icon: const Icon(Icons.qr_code_2),
                label: Text(s.signInWithFluxer),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColorScheme.surface,
        borderRadius: AppRadius.circular(18),
      ),
      child: Center(child: content),
    );
  }
}
