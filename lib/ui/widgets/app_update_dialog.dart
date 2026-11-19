import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // FLUXER:
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/app_update_service.dart';
import '../../l10n/app_localizations.dart';
import '../../util/platform_detection.dart';
import 'track_selector_dialog.dart';
import '../../fluxer/update/fluxer_android_update.dart'; // FLUXER:

/// Checks for an update and shows the dialog or an appropriate snackbar.
Future<void> checkAndShowUpdateResult(BuildContext context) async {
  final result =
      await GetIt.instance<AppUpdateService>().checkForUpdateNowDetailed();
  if (!context.mounted) return;

  final update = result.update;
  if (update != null) {
    await showAppUpdateDialog(context, update);
    return;
  }

  final l10n = AppLocalizations.of(context);
  final message = switch (result.status) {
    DesktopUpdateCheckStatus.upToDate => l10n.youAreUpToDate,
    DesktopUpdateCheckStatus.checkFailed => l10n.couldNotCheckForUpdates,
    DesktopUpdateCheckStatus.unsupportedPlatform => l10n.updateChecksNotSupported,
    DesktopUpdateCheckStatus.managedByStore => l10n.updateChecksNotSupported,
    DesktopUpdateCheckStatus.disabledByPreference => l10n.updateNotificationsDisabled,
    DesktopUpdateCheckStatus.rateLimited => l10n.pleaseWaitBeforeChecking,
    DesktopUpdateCheckStatus.alreadyNotified => l10n.latestUpdateAlreadyShown,
    DesktopUpdateCheckStatus.updateAvailable => l10n.updateAvailable,
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
  );
}

Future<void> showAppUpdateDialog(
  BuildContext context,
  DesktopUpdateInfo update,
) async {
  final l10n = AppLocalizations.of(context);

  final choice = await showStyledPlayerDialog<String>(
    context,
    title: l10n.updateAvailableTitle(update.version.replaceFirst(RegExp('^[vV]'), '')), // FLUXER: sin «vv»
    showCancel: true,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!PlatformDetection.isTV || fluxerAndroidInAppUpdate) // FLUXER: también en la tele (Android)
          _UpdateOption(
            icon: Icons.download_rounded,
            label: l10n.download,
            value: 'download',
          ),
        _UpdateOption(
          icon: Icons.article_outlined,
          label: l10n.readReleaseNotes,
          value: 'notes',
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return;

  if (choice == 'download' && fluxerAndroidInAppUpdate && update.downloadUri.isScheme('https') && update.downloadUri.path.toLowerCase().endsWith('.apk')) return fluxerDownloadAndInstallApk(context, update); // FLUXER: descargar e instalar el APK

  if (choice == 'download' &&
      Platform.isWindows &&
      update.downloadUri.isScheme('https')) {
    await _downloadAndInstallWindowsUpdate(context, update);
    return;
  }

  final uri =
      choice == 'notes' ? Uri.parse(update.releaseNotesUrl) : update.downloadUri;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// FLUXER: «Actualizar» de la pantalla de inicio: lo mismo que «Descargar».
Future<void> fluxerStartUpdate(BuildContext context, DesktopUpdateInfo update) async {
  if (fluxerAndroidInAppUpdate && update.downloadUri.isScheme('https') && update.downloadUri.path.toLowerCase().endsWith('.apk')) return fluxerDownloadAndInstallApk(context, update);
  if (Platform.isWindows && update.downloadUri.isScheme('https')) return _downloadAndInstallWindowsUpdate(context, update);
  await launchUrl(update.downloadUri, mode: LaunchMode.externalApplication);
}

Future<void> _downloadAndInstallWindowsUpdate(
  BuildContext context,
  DesktopUpdateInfo update,
) async {
  final l10n = AppLocalizations.of(context);
  final valueNotifier = ValueNotifier<double>(0.0);
  final errorNotifier = ValueNotifier<String?>(null);

  showStyledPlayerDialog<void>(
    context,
    title: l10n.updating,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: AnimatedBuilder(
          animation: Listenable.merge([valueNotifier, errorNotifier]),
          builder: (context, child) {
            final error = errorNotifier.value;
            if (error != null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        l10n.close,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }

            final progress = valueNotifier.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  try {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}moonfin_updater.exe');
    if (await file.exists()) {
      await file.delete();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(update.downloadUri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      var downloaded = 0;
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          valueNotifier.value = downloaded / contentLength;
        }
      }
      await sink.flush();
      await sink.close();
    } finally {
      client.close();
    }

    await Process.start(
      file.path,
      [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  } catch (e) {
    debugPrint('Windows in-app update failed: $e');
    errorNotifier.value = l10n.updateDownloadFailed;
  }
}

// FLUXER: hecha como la fila «Cancelar» del diálogo (Focus + OK + resaltado),
// que sí funciona con el mando de la tele; «Descargar» ya seleccionada.
class _UpdateOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;

  const _UpdateOption({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  State<_UpdateOption> createState() => _UpdateOptionState();
}

class _UpdateOptionState extends State<_UpdateOption> {
  final _focusNode = FocusNode();
  bool _focused = false;

  bool get _autofocus => widget.value == 'download';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
    if (_autofocus) {
      // En la tele, la app enfoca lo primero que encuentra en el diálogo
      // después del autofocus: se recupera aquí.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _choose() => Navigator.of(context).pop(widget.value);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: _autofocus,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          _choose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _choose,
        child: Container(
          width: double.infinity,
          color: _focused ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Icon(widget.icon, size: 22, color: Colors.white70),
              const SizedBox(width: 16),
              Text(
                widget.label,
                style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: _focused ? 0.95 : 0.8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
