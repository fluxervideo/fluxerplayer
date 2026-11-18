// FluxerPlayer: Abrir la cuenta de Fluxer en el navegador (QR en la tele).

import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/widgets/sign_in_qr_code.dart';
import '../../util/platform_detection.dart';
import '../fluxer_config.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';

/// Destinos del portal (los mismos que acepta el Hub).
const _paths = {
  'plans': '/portal/planes',
  'account': '/portal/cuenta',
  'support': '/portal/cuenta?tab=Soporte',
};

Future<void> openFluxerPortal(BuildContext context, String to, {required String title}) async {
  final url = await FluxerHubClient.instance.portalLink(to) ?? '$fluxerHubUrl${_paths[to] ?? '/portal'}';
  if (!context.mounted) return;

  if (!PlatformDetection.isTV) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }

  final s = FluxerStrings.of(context);
  final uri = Uri.parse(url);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.scanWithPhone, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          SignInQrCode(data: url, size: 240),
          const SizedBox(height: 12),
          Text(
            '${uri.host}${uri.path}',
            style: TextStyle(color: AppColorScheme.accent, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            s.portalLinkHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
      actions: [
        FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: Text(s.gotIt)),
      ],
    ),
  );
}
