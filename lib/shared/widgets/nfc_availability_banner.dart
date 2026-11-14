import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:provider/provider.dart';
import 'package:sasatap/core/nfc_service.dart';

/// Displays the current NFC hardware state and lets the user re-check it.
class NfcAvailabilityBanner extends StatefulWidget {
  const NfcAvailabilityBanner({super.key});

  @override
  State<NfcAvailabilityBanner> createState() => _NfcAvailabilityBannerState();
}

class _NfcAvailabilityBannerState extends State<NfcAvailabilityBanner> {
  bool _loading = true;
  bool _loaded = false;
  NFCAvailability? _availability;
  NfcException? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final service = context.read<NfcService>();
    try {
      final availability = await service.checkAvailability();
      if (!mounted) {
        return;
      }
      setState(() {
        _availability = availability;
        _error = null;
        _loading = false;
      });
    } on NfcException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availability = null;
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Card(
        child: ListTile(
          dense: true,
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: const Text('Checking NFC hardware…'),
        ),
      );
    }

    final error = _error;
    if (error != null) {
      return Card(
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.error_outline, color: scheme.onErrorContainer),
          title: Text(
            'Could not check NFC status',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          subtitle: Text(
            error.hint == null
                ? error.message
                : '${error.message}\n${error.hint}',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          trailing: IconButton(
            tooltip: 'Retry NFC status check',
            onPressed: _refresh,
            icon: Icon(Icons.refresh, color: scheme.onErrorContainer),
          ),
        ),
      );
    }

    final availability = _availability;
    final (IconData icon, String title, String subtitle, Color color) =
        switch (availability) {
          NFCAvailability.available => (
              Icons.check_circle_outline,
              'NFC is ready',
              'Hold a tag against the back of your phone.',
              scheme.primary,
            ),
          NFCAvailability.disabled => (
              Icons.settings_input_antenna,
              'NFC is turned off',
              'Enable NFC in your device settings, then tap refresh.',
              scheme.tertiary,
            ),
          _ => (
              Icons.error_outline,
              'NFC is not supported',
              'This device does not expose NFC hardware to the app.',
              scheme.error,
            ),
        };

    return Card(
      color: color.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          tooltip: 'Refresh NFC status',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
