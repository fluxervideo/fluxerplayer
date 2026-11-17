// FluxerPlayer: «Reportar un problema» desde la ficha de una película o
// capítulo. Llega a FluxerHub como una solicitud del cliente (Solicitudes),
// con el título y el elemento de Emby, el aparato y la app.
//
// Enganche: lib/ui/screens/detail/item_detail_screen.dart (`// FLUXER:`).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/aggregated_item.dart';
import '../fluxer_config.dart';
import '../fluxer_strings.dart';
import 'fluxer_hub_client.dart';

/// Solo para lo que se reproduce (películas, capítulos, vídeos).
bool fluxerCanReport(AggregatedItem item) =>
    const {'Movie', 'Episode', 'Video', 'MusicVideo', 'Series', 'Season'}.contains(item.type);

/// Lo mismo que el portal (MediaCustomerReport::SYMPTOMS en FluxerHub).
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
      await launchUrl(Uri.parse('$fluxerHubUrl/portal/cuenta?tab=Soporte'), mode: LaunchMode.externalApplication);
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
  final _comment = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

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

  Future<void> _send() async {
    final s = FluxerStrings.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    final item = widget.item;
    try {
      final ok = await FluxerHubClient.instance.report(
        type: 'technical_issue',
        title: _title(),
        comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        symptom: _symptom,
        embyItemId: item.id,
        embyItemType: item.type,
        seasonNumber: item.type == 'Episode' ? item.parentIndexNumber : null,
        episodeNumber: item.type == 'Episode' ? item.indexNumber : null,
      );
      if (!mounted) return;
      if (!ok) {
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
              RadioGroup<String>(
                groupValue: _symptom,
                onChanged: (v) => setState(() => _symptom = v ?? _symptom),
                child: Column(
                  children: [
                    for (final (i, key) in _symptoms.indexed)
                      RadioListTile<String>(
                        autofocus: i == 0,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: key,
                        title: Text(s.symptom(key)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 3,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: s.reportCommentHint,
                  border: const OutlineInputBorder(),
                ),
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
