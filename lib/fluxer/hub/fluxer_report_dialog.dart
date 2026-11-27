// FluxerPlayer: Reportar un problema con un título.

import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/services/log_service.dart';
import '../../ui/widgets/settings/preference_tiles.dart';
import '../widgets/fluxer_tile.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';

/// Solo para lo que se reproduce (películas, capítulos, vídeos).
bool fluxerCanReport(AggregatedItem item) =>
    const {'Movie', 'Episode', 'Video', 'MusicVideo', 'Series', 'Season'}.contains(item.type);

/// Los mismos que en la cuenta de Fluxer.
const _symptoms = ['wont_start', 'buffering', 'cuts', 'bad_quality', 'audio', 'other'];

Future<void> showFluxerReportDialog(BuildContext context, AggregatedItem item) async {
  final s = FluxerStrings.of(context);
  if (!await FluxerHubClient.instance.isLinked) {
    if (!context.mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.reportProblem),
        content: Text(s.reportNeedsFluxerLogin),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.back)),
          FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx, true), child: Text(s.openSupport)),
        ],
      ),
    );
    if (open == true) {
      if (context.mounted) await openFluxerPortal(context, 'support', title: s.openSupport);
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => _ReportDialog(item: item));
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.item});

  final AggregatedItem item;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _symptom = 'wont_start';
  // Con «Otra cosa»: la opción de la lista larga (FluxerStrings.reportOtherOptions).
  String? _otherKey;
  // Solo si el cliente tiene activado «Grabar diagnóstico» (Mi cuenta Fluxer).
  final bool _canAttach = GetIt.instance<LogService>().isEnabled;
  bool _attachDiagnostic = true;
  bool _sending = false;
  String? _error;

  /// «Serie · T2E5 · Título» o «Película (2021)».
  String _title() {
    final item = widget.item;
    final year = item.productionYear;
    if (item.type == 'Episode') {
      final se = [
        if (item.parentIndexNumber != null) 'T${item.parentIndexNumber}',
        if (item.indexNumber != null) 'E${item.indexNumber}',
      ].join();
      return [item.seriesName, se, item.name].where((p) => p != null && p.isNotEmpty).join(' · ');
    }
    return year != null ? '${item.name} ($year)' : item.name;
  }

  /// La opción de «Otra cosa», en español para quien lo revisa en el Hub.
  String? _otherComment() {
    if (_symptom != 'other' || _otherKey == null) return null;
    for (final o in FluxerStrings.reportOtherOptions) {
      if (o.$2 == _otherKey) return 'Otra cosa: ${o.$3}';
    }
    return null;
  }

  Future<void> _send() async {
    final s = FluxerStrings.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    final item = widget.item;
    try {
      final id = await FluxerHubClient.instance.report(
        type: 'technical_issue',
        title: _title(),
        symptom: _symptom,
        comment: _otherComment(),
        embyItemId: item.id,
        embyItemType: item.type,
        seasonNumber: item.type == 'Episode' ? item.parentIndexNumber : null,
        episodeNumber: item.type == 'Episode' ? item.indexNumber : null,
      );
      if (id != null && id > 0 && _canAttach && _attachDiagnostic) {
        try {
          await FluxerHubClient.instance.diagnostics(
            GetIt.instance<LogService>().exportText(maxEntries: 5000),
            reportId: id,
          );
        } catch (_) {
          // El reporte ya llegó; sin diagnóstico no se pierde nada importante.
        }
      }
      if (!mounted) return;
      if (id == null) {
        setState(() {
          _sending = false;
          _error = s.reportNeedsFluxerLogin;
        });
        return;
      }
      Navigator.pop(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(s.reportSent)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = s.reportFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    return AlertDialog(
      title: Text(s.reportProblem),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title(), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(s.reportWhatHappens),
              // Opciones de Ajustes (SettingsPickerOption), no RadioListTile:
              // en la tele el grupo de radios se quedaba con ↑/↓ y el botón
              // central no elegía, así que no se llegaba al comentario ni a Enviar.
              for (final (i, key) in _symptoms.indexed)
                SettingsPickerOption(
                  autofocus: i == 0,
                  label: s.symptom(key),
                  selected: _symptom == key,
                  onTap: () => setState(() => _symptom = key),
                ),
              if (_symptom == 'other') ...[
                const SizedBox(height: 12),
                Text(s.reportOtherWhat),
                for (final (i, o) in FluxerStrings.reportOtherOptions.indexed) ...[
                  if (i == 0 || FluxerStrings.reportOtherOptions[i - 1].$1 != o.$1)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: Text(
                        s.reportOtherGroup(o.$1),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  SettingsPickerOption(
                    label: s.reportOtherLabel(o),
                    selected: _otherKey == o.$2,
                    onTap: () => setState(() => _otherKey = o.$2),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  s.reportMoreDetailsWeb,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              if (_canAttach)
                FluxerTile(
                  leading: Icon(_attachDiagnostic ? Icons.check_box : Icons.check_box_outline_blank),
                  title: Text(s.attachDiagnostic),
                  trailing: const SizedBox.shrink(),
                  onTap: () => setState(() => _attachDiagnostic = !_attachDiagnostic),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: Text(s.back)),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.send),
        ),
      ],
    );
  }
}
