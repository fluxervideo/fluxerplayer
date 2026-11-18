// FluxerPlayer: actualizar desde la app en Android (móvil, Android TV,
// Google TV, Fire TV), como Moonfin ya hace en Windows.
//
// Moonfin comprueba las versiones de GitHub y saca el aviso; en Android solo
// abría el APK en el navegador (y en la tele ni eso: no hay navegador). Aquí
// se completa: «Descargar» baja el APK (el de tele o el de móvil, lo elige
// Moonfin) con una barra de progreso y abre el instalador de Android. La
// primera vez Android pide permitir que FluxerPlayer instale apps.
//
// Enganches (`// FLUXER:`): lib/ui/widgets/app_update_dialog.dart (Ajustes →
// Acerca de → Buscar actualizaciones) y app_update_banner.dart (el aviso
// automático: en el móvil «Descargar» instala; en la tele, donde la pastilla
// no se puede pulsar con el mando, sale el diálogo de actualizar).
// Nativo: android/.../org/fluxer/FluxerApkInstaller.kt.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/app_update_service.dart';
import '../../ui/navigation/app_router.dart';
import '../../ui/widgets/app_update_dialog.dart';
import '../../util/app_distribution.dart';
import '../../util/platform_detection.dart';
import '../fluxer_strings.dart';

const _channel = MethodChannel('fluxer/apk_installer');
const _fileName = 'FluxerPlayer-update.apk';

/// ¿Esta copia se actualiza descargando el APK desde la app?
bool get fluxerAndroidInAppUpdate =>
    !kIsWeb &&
    Platform.isAndroid &&
    (AppDistribution.channel == DistributionChannel.apk || AppDistribution.channel == DistributionChannel.androidTvApk);

/// Descarga el APK de [update] y abre el instalador de Android.
Future<void> fluxerDownloadAndInstallApk(BuildContext context, DesktopUpdateInfo update) async {
  final s = FluxerStrings.of(context);
  final progress = ValueNotifier<double?>(null);
  final error = ValueNotifier<String?>(null);
  final cancel = CancelToken();
  var dialogOpen = true;

  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(s.updateDownloading(update.version)),
      content: SizedBox(
        width: 420,
        child: AnimatedBuilder(
          animation: Listenable.merge([progress, error]),
          builder: (_, _) {
            final message = error.value;
            if (message != null) return Text(message, style: const TextStyle(color: Colors.redAccent));
            final value = progress.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value, minHeight: 8),
                const SizedBox(height: 12),
                Text(value == null ? s.updatePreparing : '${(value * 100).toStringAsFixed(0)} %'),
                const SizedBox(height: 8),
                Text(s.updateInstallHint, style: const TextStyle(fontSize: 12)),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () {
            cancel.cancel();
            Navigator.of(ctx).pop();
          },
          child: Text(s.cancel),
        ),
      ],
    ),
  ).whenComplete(() => dialogOpen = false);

  try {
    final dir = Directory('${(await getTemporaryDirectory()).path}/fluxer_update');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final path = '${dir.path}/$_fileName';

    await Dio().downloadUri(
      update.downloadUri,
      path,
      cancelToken: cancel,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );
    if (cancel.isCancelled) return;

    await _channel.invokeMethod<bool>('install', {'name': _fileName});
    if (dialogOpen && context.mounted) Navigator.of(context, rootNavigator: true).pop();
  } catch (e) {
    if (cancel.isCancelled) return;
    debugPrint('FluxerPlayer: no se ha podido actualizar: $e');
    error.value = s.updateFailed;
  }
  await dialog;
}

/// El aviso automático de versión nueva (app_update_banner.dart), en Android:
/// en el móvil descarga e instala; en la tele enseña el diálogo para
/// elegir con el mando. Devuelve false si no hay dónde enseñarlo.
bool fluxerOfferAndroidUpdate(DesktopUpdateInfo update, {required bool fromButton}) {
  final context = appRouter.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return false;
  if (fromButton) {
    fluxerDownloadAndInstallApk(context, update);
  } else if (PlatformDetection.useLeanbackUi) {
    showAppUpdateDialog(context, update);
  } else {
    return false;
  }
  return true;
}
