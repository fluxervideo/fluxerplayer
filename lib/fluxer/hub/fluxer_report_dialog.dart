// FluxerPlayer: Reportar un problema con un título.

import 'package:flutter/material.dart';

import 'package:get_it/get_it.dart';

import '../../data/models/aggregated_item.dart';
import '../../data/services/log_service.dart';
import '../../ui/widgets/settings/preference_tiles.dart';
import '../../util/platform_detection.dart';
import '../widgets/fluxer_tile.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';
import 'fluxer_portal.dart';

/// Solo para lo que se reproduce (películas, capítulos, vídeos).
bool fluxerCanReport(AggregatedItem item) =>
    const {'Movie', 'Episode', 'Video', 'MusicVideo', 'Series', 'Season'}.contains(item.type);

/// Opciones de la lista: (clave, síntoma que acepta el Hub). Las dos de
/// idioma y título equivocado van al Hub como «Otra cosa» con su texto en el
/// comentario (el Hub solo acepta los seis síntomas de la cuenta de Fluxer).
const _options = [
  ('wont_start', 'wont_start'),
  ('buffering', 'buffering'),
  ('cuts', 'cuts'),
  ('bad_quality', 'bad_quality'),
  ('audio', 'audio'),
  ('lang_missing', 'other'),
  ('wrong_item', 'other'),
  ('other', 'other'),
];

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
  String _option = 'wont_start';
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

  /// «Otra cosa»: ventana con una caja de texto; al enviarla, se manda el
  /// reporte con lo escrito.
  Future<void> _askOther() async {
    final text = await showDialog<String>(context: context, builder: (_) => const _OtherDialog());
    if (text == null || !mounted) return;
    setState(() => _option = 'other');
    await _send(comment: text);
  }

  Future<void> _send({String? comment}) async {
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
        symptom: _options.firstWhere((o) => o.$1 == _option).$2,
        // Las opciones que el Hub no tiene, en español para quien lo revisa.
        comment: comment ?? FluxerStrings.reportCommentFor(_option),
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
              for (final (i, (key, _)) in _options.indexed)
                SettingsPickerOption(
                  autofocus: i == 0,
                  label: s.symptom(key),
                  selected: _option == key,
                  onTap: _sending
                      ? () {}
                      : key == 'other'
                          ? _askOther
                          : () => setState(() => _option = key),
                ),
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
          onPressed: _sending ? null : () => _option == 'other' ? _askOther() : _send(),
          child: _sending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(s.send),
        ),
      ],
    );
  }
}

/// «Otra cosa»: caja de texto con el foco puesto. Enter (o «Enviar» del
/// teclado) envía; en la tele, ↑/↓ saltan entre la caja y los botones.
class _OtherDialog extends StatefulWidget {
  const _OtherDialog();

  @override
  State<_OtherDialog> createState() => _OtherDialogState();
}

class _OtherDialogState extends State<_OtherDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasText => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (_hasText) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    return AlertDialog(
      title: Text(s.reportOtherTitle),
      content: SizedBox(
        width: 520,
        child: FluxerTvTextFieldEscape(
          enabled: PlatformDetection.isTV,
          child: TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: s.reportOtherHint,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.back)),
        FilledButton(onPressed: _hasText ? _submit : null, child: Text(s.send)),
      ],
    );
  }
}
