// FluxerPlayer: Test de velocidad contra el servidor de Fluxer.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../ui/screens/settings/settings_app_bar.dart';
import '../../ui/widgets/focus/request_initial_focus.dart';
import '../fluxer_strings.dart';
import '../widgets/fluxer_tile.dart';
import 'fluxer_hub_client.dart';

class FluxerSpeedTestScreen extends StatefulWidget {
  const FluxerSpeedTestScreen({super.key});

  @override
  State<FluxerSpeedTestScreen> createState() => _FluxerSpeedTestScreenState();
}

enum _Phase { loading, choose, latency, download, sending, result, error }

class _FluxerSpeedTestScreenState extends State<FluxerSpeedTestScreen> {
  final _client = FluxerHubClient.instance;

  _Phase _phase = _Phase.loading;
  Map<String, dynamic>? _options;
  Map<String, dynamic>? _result;
  String? _error;
  double _fraction = 0;
  double? _currentMbps;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    Map<String, dynamic>? options;
    try {
      options = await _client.speedTestOptions();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _options = options;
      _phase = options == null ? _Phase.error : _Phase.choose;
      if (options == null) _error = FluxerStrings.of(context).speedTestUnavailable;
    });
  }

  Future<void> _run(int? eventId) async {
    final s = FluxerStrings.of(context);
    setState(() {
      _phase = _Phase.latency;
      _fraction = 0;
      _currentMbps = null;
      _error = null;
    });
    try {
      final started = await _client.speedTestStart(eventId);
      if (started == null) throw FluxerHubMessage(s.speedTestUnavailable);
      final test = (started['test'] as Map).cast<String, dynamic>();
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

      final latencies = await _measureLatency(dio, started['ping_url'] as String);
      if (!mounted) return;
      setState(() => _phase = _Phase.download);
      final download = await _measureDownload(
        dio,
        url: started['video_url'] as String,
        totalBytes: (started['bytes'] as num).toInt(),
        maxSeconds: (started['max_seconds'] as num).toInt(),
        windowMs: (started['window_ms'] as num).toInt(),
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.sending);
      final result = await _client.speedTestResult((test['id'] as num).toInt(), {
        ...download,
        'latencies_ms': latencies,
      });
      if (!mounted) return;
      setState(() {
        _result = result;
        _phase = result == null ? _Phase.error : _Phase.result;
        if (result == null) _error = s.speedTestUnavailable;
      });
    } on FluxerHubMessage catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message ?? s.speedTestUnavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = s.speedTestUnavailable;
      });
    }
  }

  /// 6 peticiones vacías al servidor; la primera abre la conexión y no cuenta.
  Future<List<int>> _measureLatency(Dio dio, String pingUrl) async {
    final out = <int>[];
    for (var i = 0; i < 6; i++) {
      final sw = Stopwatch()..start();
      try {
        await dio.get<dynamic>(
          '$pingUrl?r=${DateTime.now().millisecondsSinceEpoch}-$i',
          options: Options(responseType: ResponseType.plain, validateStatus: (_) => true),
        );
      } catch (_) {
        continue;
      }
      if (i > 0) out.add(sw.elapsedMilliseconds);
    }
    return out;
  }

  /// Baja el tramo como mucho [maxSeconds] desde el primer byte. Devuelve los
  /// bytes de cada ventana completa (la última, a medias, no cuenta).
  Future<Map<String, dynamic>> _measureDownload(
    Dio dio, {
    required String url,
    required int totalBytes,
    required int maxSeconds,
    required int windowMs,
  }) async {
    final cancel = _cancel = CancelToken();
    final sw = Stopwatch()..start();
    final perWindow = <int, int>{};
    var bytes = 0;
    int? firstByteAt;
    var end = 0;
    int? status;
    String? error;
    var lastPaint = 0;

    try {
      final response = await dio.get<ResponseBody>(
        url,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration(seconds: maxSeconds + 20),
          validateStatus: (_) => true,
          headers: const {'Cache-Control': 'no-store'},
        ),
      );
      status = response.statusCode;
      final body = response.data;
      if ((status != 200 && status != 206) || body == null) {
        throw Exception('HTTP $status');
      }
      await for (final chunk in body.stream) {
        final now = sw.elapsedMilliseconds;
        firstByteAt ??= now;
        final w = (now - firstByteAt) ~/ windowMs;
        perWindow[w] = (perWindow[w] ?? 0) + chunk.length;
        bytes += chunk.length;
        end = now;
        if (now - lastPaint > 200 && mounted) {
          lastPaint = now;
          var lastSecond = 0;
          for (var i = w - 3; i <= w; i++) {
            lastSecond += perWindow[i] ?? 0;
          }
          final span = (w + 1).clamp(1, 4) * windowMs;
          setState(() {
            final byTime = (now - firstByteAt!) / (maxSeconds * 1000);
            _fraction = (bytes / totalBytes > byTime ? bytes / totalBytes : byTime).clamp(0.0, 1.0);
            _currentMbps = w >= 1 ? lastSecond * 8 / (span / 1000) / 1e6 : null;
          });
        }
        if (now - firstByteAt > maxSeconds * 1000) break;
      }
    } catch (e) {
      error = e is DioException && e.type == DioExceptionType.receiveTimeout
          ? 'La descarga tardó demasiado.'
          : 'No se ha podido descargar del servidor.';
    } finally {
      if (!cancel.isCancelled) cancel.cancel();
    }

    final first = firstByteAt;
    final fullWindows = first == null ? 0 : (end - first) ~/ windowMs;
    return {
      'samples': [for (var i = 0; i < fullWindows.clamp(0, 400); i++) perWindow[i] ?? 0],
      'bytes': bytes,
      'seconds': first == null ? 0 : (end - first) / 1000,
      'ttfb_ms': first,
      'http_status': status,
      'error': bytes > 0 ? null : error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    return RequestInitialFocus(
      child: Scaffold(
        appBar: buildSettingsAppBar(context, Text(s.speedTest)),
        body: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.choose => _choose(s),
          _Phase.latency || _Phase.download || _Phase.sending => _running(s),
          _Phase.result => _resultView(s),
          _Phase.error => _errorView(s),
        },
      ),
    );
  }

  Widget _choose(FluxerStrings s) {
    final options = _options ?? const {};
    final items = (options['items'] as List?)?.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() ?? const [];
    final sample = (options['sample_video'] as Map?)?.cast<String, dynamic>();
    final blocked = options['blocked'] as String?;
    final available = options['available'] == true;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(s.speedTestIntro, style: TextStyle(color: AppColorScheme.onSurface.withValues(alpha: 0.8))),
        ),
        if (blocked != null)
          _notice(blocked, Icons.timer_outlined)
        else if (!available)
          _notice(s.speedTestUnavailable, Icons.info_outline)
        else if (items.isEmpty && sample != null)
          FluxerTile(
            autofocus: true,
            leading: const Icon(Icons.speed),
            title: Text(s.speedTestSample),
            subtitle: Text('${sample['title']} · ${sample['server_name']}'),
            onTap: () => _run(null),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              s.speedTestPick(options['recent_days'] as int? ?? 7),
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColorScheme.accent),
            ),
          ),
          for (final (i, item) in items.indexed)
            FluxerTile(
              autofocus: i == 0,
              leading: _poster(item['poster_url'] as String?),
              title: Text(item['title'] as String? ?? ''),
              subtitle: Text([
                if (item['series_name'] != null) item['series_name'] as String,
                if (item['device_name'] != null) item['device_name'] as String,
              ].join(' · ')),
              onTap: () => _run((item['event_id'] as num).toInt()),
            ),
        ],
      ],
    );
  }

  Widget _poster(String? url) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: 36,
      height: 54,
      child: url == null
          ? const Icon(Icons.movie_outlined)
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie_outlined)),
    ),
  );

  Widget _notice(String text, IconData icon) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColorScheme.accent),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _running(FluxerStrings s) {
    final label = switch (_phase) {
      _Phase.latency => s.speedTestLatency,
      _Phase.sending => s.speedTestSending,
      _ => s.speedTestDownloading,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentMbps == null ? '—' : '${_currentMbps!.toStringAsFixed(_currentMbps! < 10 ? 1 : 0)} Mbps',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _phase == _Phase.download ? _fraction : null,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 14),
              Text(label, style: TextStyle(color: AppColorScheme.onSurface.withValues(alpha: 0.75))),
              const SizedBox(height: 6),
              Text(s.speedTestDontLeave, style: TextStyle(fontSize: 12, color: AppColorScheme.onSurface.withValues(alpha: 0.55))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultView(FluxerStrings s) {
    final r = _result ?? const {};
    final verdict = r['verdict'] as String?;
    final failed = r['status'] != 'done';
    final (Color tone, IconData icon, String title, String help) = failed
        ? (AppColorScheme.statusRequested, Icons.error_outline, s.speedTestFailed, (r['error'] as String?) ?? '')
        : switch (verdict) {
            'plenty' => (AppColorScheme.statusAvailable, Icons.check_circle_outline, s.verdictPlenty, s.verdictPlentyHelp),
            'tight' => (const Color(0xFFF5A623), Icons.warning_amber_rounded, s.verdictTight, s.verdictTightHelp),
            'insufficient' => (AppColorScheme.statusRequested, Icons.cancel_outlined, s.verdictInsufficient, s.verdictInsufficientHelp),
            _ => (AppColorScheme.accent, Icons.speed, s.speedTestDone, ''),
          };
    String mbps(Object? v) => v is num ? '${v.toStringAsFixed(v < 10 ? 1 : 0)} Mbps' : '—';
    final height = (r['video_height'] as num?)?.toInt();
    final quality = height == null
        ? null
        : height >= 1800
            ? '4K'
            : height >= 1000
                ? '1080p'
                : height >= 700
                    ? '720p'
                    : 'SD';

    final rows = <(String, String)>[
      if (!failed) (s.speedAverage, mbps(r['avg_mbps'])),
      if (r['needed_mbps'] != null) (s.speedNeeded(quality), mbps(r['needed_mbps'])),
      if (!failed) (s.speedMinMax, '${mbps(r['min_mbps'])} / ${mbps(r['max_mbps'])}'),
      if (r['latency_ms'] != null) (s.speedLatency, '${r['latency_ms']} ms'),
      if (r['server_mbps'] != null) (s.speedServer, mbps(r['server_mbps'])),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(icon, color: tone, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: tone)),
                  if (r['title'] != null)
                    Text(
                      [r['series_name'], r['title']].whereType<String>().join(' · '),
                      style: TextStyle(color: AppColorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (help.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(help, style: const TextStyle(height: 1.35)),
        ],
        const SizedBox(height: 16),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(label, style: TextStyle(color: AppColorScheme.onSurface.withValues(alpha: 0.75)))),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FluxerTile(
          autofocus: true,
          leading: const Icon(Icons.refresh),
          title: Text(s.speedTestAgain),
          onTap: _loadOptions,
        ),
      ],
    );
  }

  Widget _errorView(FluxerStrings s) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _notice(_error ?? s.speedTestUnavailable, Icons.error_outline),
      FluxerTile(
        autofocus: true,
        leading: const Icon(Icons.refresh),
        title: Text(s.speedTestAgain),
        onTap: _loadOptions,
      ),
    ],
  );
}
