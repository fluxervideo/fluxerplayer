// FluxerPlayer: Recargar saldo: método, importe, código de concepto y espera del pago.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonfin_design/moonfin_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/widgets/focus/request_initial_focus.dart';
import '../../ui/widgets/sign_in_qr_code.dart';
import '../../util/focus/dpad_keys.dart';
import '../../util/platform_detection.dart';
import '../fluxer_strings.dart';
import '../widgets/fluxer_tile.dart';
import 'fluxer_hub_client.dart';

/// Abre «Recargar saldo» encima de todo (menú del usuario, Ajustes…).
Future<void> openFluxerRecharge(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(builder: (_) => const FluxerRechargeScreen()));

/// Logos de los métodos de pago, por código.
const _methodIcons = {
  'paypal': 'assets/icons/fluxer_pay_paypal.svg',
  'bizum': 'assets/icons/fluxer_pay_bizum.svg',
};

class FluxerRechargeScreen extends StatefulWidget {
  const FluxerRechargeScreen({super.key});

  @override
  State<FluxerRechargeScreen> createState() => _FluxerRechargeScreenState();
}

enum _Step { loading, method, pay, waiting, done, error }

class _FluxerRechargeScreenState extends State<FluxerRechargeScreen> with WidgetsBindingObserver {
  static const _checkEvery = Duration(seconds: 30);
  static const _supportAfter = Duration(minutes: 10);

  final _client = FluxerHubClient.instance;
  final _amountController = TextEditingController();

  _Step _step = _Step.loading;
  Map<String, dynamic>? _options;
  Map<String, dynamic>? _method;
  String? _concept;
  double? _amount;
  bool _customAmount = false;
  bool _submitting = false;
  String? _error;

  int? _rechargeId;
  DateTime? _waitingSince;
  Timer? _timer;
  bool _showSupport = false;
  bool _rejected = false;
  double? _addedAmount;
  double? _newBalance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  // Ha ido a PayPal o al banco y vuelve: se comprueba ya.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.waiting) _check();
  }

  List<Map<String, dynamic>> _list(String key) =>
      (_options?[key] as List?)?.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() ?? const [];

  Future<void> _load() async {
    setState(() {
      _step = _Step.loading;
      _error = null;
    });
    Map<String, dynamic>? options;
    try {
      options = await _client.rechargeOptions();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _options = options;
      _step = options == null ? _Step.error : _Step.method;
      if (options == null) _error = FluxerStrings.of(context).rechargeUnavailable;
    });
  }

  Future<void> _chooseMethod(Map<String, dynamic> method) async {
    setState(() {
      _method = method;
      _concept = null;
      _amount = null;
      _customAmount = false;
      _amountController.clear();
      _error = null;
      _step = _Step.pay;
    });
    try {
      final code = await _client.rechargeCode(method['code'] as String);
      if (!mounted || _method != method) return;
      setState(() => _concept = code);
      if (code == null) setState(() => _error = FluxerStrings.of(context).rechargeUnavailable);
    } on FluxerHubMessage catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? FluxerStrings.of(context).rechargeUnavailable);
    }
  }

  double? get _effectiveAmount {
    if (!_customAmount) return _amount;
    final v = double.tryParse(_amountController.text.replaceAll(',', '.').trim());
    return v != null && v > 0 ? v : null;
  }

  Future<void> _submit() async {
    final method = _method;
    final concept = _concept;
    if (method == null || concept == null) return;
    final s = FluxerStrings.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _client.rechargeRequest(method['code'] as String, _effectiveAmount, concept);
      if (!mounted) return;
      if (result == null) {
        setState(() {
          _submitting = false;
          _error = s.rechargeUnavailable;
        });
        return;
      }
      _rechargeId = (result['id'] as num).toInt();
      _waitingSince = DateTime.now();
      _showSupport = false;
      _rejected = false;
      setState(() {
        _submitting = false;
        _step = _Step.waiting;
      });
      _apply(result);
      _timer?.cancel();
      _timer = Timer.periodic(_checkEvery, (_) => _check());
    } on FluxerHubMessage catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message ?? s.rechargeUnavailable;
      });
    }
  }

  Future<void> _check() async {
    final id = _rechargeId;
    if (id == null || _step != _Step.waiting) return;
    final result = await _client.rechargeStatus(id);
    if (!mounted || _step != _Step.waiting) return;
    if (result != null) _apply(result);
    final since = _waitingSince;
    if (_step == _Step.waiting && since != null && DateTime.now().difference(since) >= _supportAfter && !_showSupport) {
      setState(() => _showSupport = true);
    }
  }

  void _apply(Map<String, dynamic> result) {
    switch (result['status']) {
      case 'completed':
        _timer?.cancel();
        unawaited(_client.me(fresh: true));
        setState(() {
          _addedAmount = (result['amount'] as num?)?.toDouble();
          _newBalance = (result['balance'] as num?)?.toDouble();
          _step = _Step.done;
        });
      case 'rejected':
        _timer?.cancel();
        setState(() {
          _rejected = true;
          _showSupport = true;
        });
    }
  }

  Future<void> _copy(String text, String message) async {
    if (PlatformDetection.isTV) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _openSupport() async {
    final url = _options?['support_url'] as String?;
    if (url == null) return;
    final s = FluxerStrings.of(context);
    if (!PlatformDetection.isTV) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.supportTelegram),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.scanWithPhone, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SignInQrCode(data: url, size: 220),
            const SizedBox(height: 12),
            Text(Uri.parse(url).host + Uri.parse(url).path, style: TextStyle(color: AppColorScheme.accent, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [FilledButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: Text(s.gotIt))],
      ),
    );
  }

  // ───────────────────────────── Pantallas ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = FluxerStrings.of(context);
    final canGoBackInside = _step == _Step.pay;
    return PopScope(
      canPop: !canGoBackInside,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && canGoBackInside) setState(() => _step = _Step.method);
      },
      child: RequestInitialFocus(
        key: ValueKey(_step),
        child: Scaffold(
          appBar: AppBar(title: Text(_step == _Step.pay ? (_method?['name'] as String? ?? s.recharge) : s.recharge)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: switch (_step) {
                _Step.loading => const Center(child: CircularProgressIndicator()),
                _Step.method => _methodStep(s),
                _Step.pay => _payStep(s),
                _Step.waiting => _waitingStep(s),
                _Step.done => _doneStep(s),
                _Step.error => _errorStep(s),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _methodStep(FluxerStrings s) {
    final methods = _list('methods');
    final balance = (_options?['balance'] as num?)?.toDouble();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (balance != null)
          Text(s.balanceLine(balance), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(s.rechargeIntro, style: TextStyle(color: _muted, height: 1.4)),
        const SizedBox(height: 20),
        if (methods.isEmpty)
          Text(s.rechargeNoMethods, style: TextStyle(color: _muted))
        else
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final (i, m) in methods.indexed)
                _MethodTile(
                  autofocus: i == 0,
                  name: m['name'] as String? ?? '',
                  icon: _methodIcons[m['code']],
                  onTap: () => _chooseMethod(m),
                ),
            ],
          ),
      ],
    );
  }

  Widget _payStep(FluxerStrings s) {
    final method = _method ?? const {};
    final amounts = _list('amounts');
    final destination = method['destination'] as String?;
    final comment = method['comment'] as String?;
    final amount = _effectiveAmount;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.rechargeHowMuch, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, a) in amounts.indexed)
              _AmountChip(
                autofocus: i == 0,
                label: a['label'] as String? ?? '',
                price: (a['price'] as num).toDouble(),
                selected: !_customAmount && _amount == (a['price'] as num).toDouble(),
                onTap: () => setState(() {
                  _customAmount = false;
                  _amount = (a['price'] as num).toDouble();
                }),
              ),
            _AmountChip(
              autofocus: amounts.isEmpty,
              label: s.otherAmount,
              selected: _customAmount,
              onTap: () => setState(() => _customAmount = true),
            ),
          ],
        ),
        if (_customAmount) ...[
          const SizedBox(height: 12),
          FluxerTvTextFieldEscape(
            enabled: PlatformDetection.isTV,
            child: TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(labelText: s.amountEuros, suffixText: '€', border: const OutlineInputBorder()),
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (destination != null && destination.isNotEmpty)
          _InfoBox(
            label: amount == null ? s.sendTo(method['name'] as String?) : s.sendAmountTo(amount, method['name'] as String?),
            value: destination,
            copyable: !PlatformDetection.isTV,
            onTap: () => _copy(destination, s.copied),
          ),
        const SizedBox(height: 14),
        _InfoBox(
          label: s.putThisConcept,
          value: _concept ?? '····',
          big: true,
          highlight: true,
          copyable: !PlatformDetection.isTV && _concept != null,
          onTap: _concept == null ? null : () => _copy(_concept!, s.codeCopied),
          footer: comment?.isNotEmpty == true ? comment : s.conceptWhy,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _submitting || _concept == null ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(s.rechargePaid, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 10),
        Text(s.rechargeSelfPay, style: TextStyle(fontSize: 12, color: _muted)),
      ],
    );
  }

  Widget _waitingStep(FluxerStrings s) {
    final method = _method ?? const {};
    final destination = method['destination'] as String?;
    final amount = _effectiveAmount;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!_rejected)
          Row(
            children: [
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 14),
              Expanded(child: Text(s.rechargeWaiting, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            ],
          ),
        if (!_rejected) ...[
          const SizedBox(height: 8),
          Text(s.rechargeWaitingHelp, style: TextStyle(color: _muted, height: 1.4)),
        ],
        const SizedBox(height: 18),
        if (destination != null && destination.isNotEmpty)
          _InfoBox(
            label: amount == null ? s.sendTo(method['name'] as String?) : s.sendAmountTo(amount, method['name'] as String?),
            value: destination,
            copyable: !PlatformDetection.isTV,
            onTap: () => _copy(destination, s.copied),
          ),
        const SizedBox(height: 14),
        _InfoBox(
          label: s.putThisConcept,
          value: _concept ?? '',
          big: true,
          highlight: true,
          copyable: !PlatformDetection.isTV,
          onTap: () => _copy(_concept ?? '', s.codeCopied),
        ),
        if (_showSupport) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF5A623).withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _rejected ? s.rechargeRejected : s.rechargeLate,
                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 10),
                FluxerTile(
                  autofocus: true,
                  leading: const Icon(Icons.send_rounded),
                  title: Text(s.supportTelegram),
                  subtitle: Text(PlatformDetection.isTV ? s.supportTelegramTv : s.supportTelegramHelp),
                  onTap: _openSupport,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        FluxerTile(
          autofocus: !_showSupport,
          leading: const Icon(Icons.arrow_back),
          title: Text(s.rechargeLeave),
          subtitle: Text(s.rechargeLeaveHelp),
          trailing: const SizedBox.shrink(),
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _doneStep(FluxerStrings s) => ListView(
    padding: const EdgeInsets.all(28),
    children: [
      Icon(Icons.check_circle_outline, size: 64, color: AppColorScheme.statusAvailable),
      const SizedBox(height: 14),
      Text(
        _addedAmount == null ? s.rechargeDone : s.rechargeDoneAmount(_addedAmount!),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      if (_newBalance != null) ...[
        const SizedBox(height: 8),
        Text(s.balanceLine(_newBalance!), textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _muted)),
      ],
      const SizedBox(height: 10),
      Text(s.rechargeDoneHelp, textAlign: TextAlign.center, style: TextStyle(color: _muted, height: 1.4)),
      const SizedBox(height: 24),
      Center(
        child: FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), child: Text(s.gotIt)),
        ),
      ),
    ],
  );

  Widget _errorStep(FluxerStrings s) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(_error ?? s.rechargeUnavailable),
      const SizedBox(height: 16),
      FluxerTile(autofocus: true, leading: const Icon(Icons.refresh), title: Text(s.retry), onTap: _load),
    ],
  );

  Color get _muted => AppColorScheme.onSurface.withValues(alpha: 0.72);
}

/// Un método de pago: su logo sobre blanco.
class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.name, required this.icon, required this.onTap, this.autofocus = false});

  final String name;
  final String? icon;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return _Focusable(
      autofocus: autofocus,
      onTap: onTap,
      radius: 18,
      builder: (focused) => SizedBox(
        width: 150,
        child: Column(
          children: [
            Container(
              width: 150,
              height: 110,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: icon != null
                  ? SvgPicture.asset(icon!, fit: BoxFit.contain)
                  : const Icon(Icons.account_balance_wallet_outlined, size: 40, color: Color(0xFF1A2230)),
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label, this.price, required this.selected, required this.onTap, this.autofocus = false});

  final String label;
  final double? price;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final accent = AppColorScheme.accent;
    return _Focusable(
      autofocus: autofocus,
      onTap: onTap,
      radius: 14,
      builder: (focused) => Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : AppColorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accent : AppColorScheme.onSurface.withValues(alpha: 0.15), width: selected ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (price != null)
              Text('${price!.toStringAsFixed(2)} €', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: price == null ? 15 : 12, fontWeight: price == null ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// Recuadro con un dato que se copia al tocarlo (no en la tele).
class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    this.onTap,
    this.copyable = false,
    this.big = false,
    this.highlight = false,
    this.footer,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool copyable;
  final bool big;
  final bool highlight;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final accent = AppColorScheme.accent;
    final box = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? accent.withValues(alpha: 0.12) : AppColorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? accent.withValues(alpha: 0.45) : AppColorScheme.onSurface.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColorScheme.onSurface.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: big ? 34 : 17,
                    fontWeight: big ? FontWeight.w800 : FontWeight.w700,
                    letterSpacing: big ? 6 : 0,
                    color: big ? accent : null,
                  ),
                ),
              ),
              if (copyable) Icon(Icons.copy_rounded, size: 20, color: AppColorScheme.onSurface.withValues(alpha: 0.6)),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(footer!, style: TextStyle(fontSize: 12, color: AppColorScheme.onSurface.withValues(alpha: 0.65))),
          ],
        ],
      ),
    );
    if (!copyable || onTap == null) return box;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: box);
  }
}

/// Se puede elegir con el mando: borde al tener el foco, botón central o
/// Enter pulsa.
class _Focusable extends StatefulWidget {
  const _Focusable({required this.builder, required this.onTap, required this.radius, this.autofocus = false});

  final Widget Function(bool focused) builder;
  final VoidCallback onTap;
  final double radius;
  final bool autofocus;

  @override
  State<_Focusable> createState() => _FocusableState();
}

class _FocusableState extends State<_Focusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
      },
      onKeyEvent: (_, event) {
        if (!event.logicalKey.isSelectKey) return KeyEventResult.ignored;
        if (event is KeyDownEvent) widget.onTap();
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius + 3),
            border: Border.all(color: _focused ? AppColorScheme.accent : Colors.transparent, width: 3),
          ),
          child: MouseRegion(cursor: SystemMouseCursors.click, child: widget.builder(_focused)),
        ),
      ),
    );
  }
}
