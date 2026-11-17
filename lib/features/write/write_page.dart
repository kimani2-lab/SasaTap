import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:provider/provider.dart';
import 'package:sasatap/core/hex_utils.dart';
import 'package:sasatap/core/ndef_builder.dart';
import 'package:sasatap/core/ndef_inspector.dart';
import 'package:sasatap/core/nfc_service.dart';
import 'package:sasatap/features/saved/saved_tag_repository.dart';
import 'package:sasatap/features/write/write_provider.dart';
import 'package:sasatap/shared/utils/tag_lock_flow.dart';
import 'package:sasatap/shared/utils/ui_helpers.dart';
import 'package:sasatap/shared/widgets/section_card.dart';

enum _DraftType { uri, text, vCard, wifi, customMime }

class _DraftRecord {
  const _DraftRecord({required this.type, required this.record});

  final _DraftType type;
  final ndef.NDEFRecord record;
}

extension on _DraftType {
  String get label {
    switch (this) {
      case _DraftType.uri:
        return 'URL / URI';
      case _DraftType.text:
        return 'Text';
      case _DraftType.vCard:
        return 'vCard';
      case _DraftType.wifi:
        return 'Wi-Fi';
      case _DraftType.customMime:
        return 'Custom MIME';
    }
  }

  IconData get icon {
    switch (this) {
      case _DraftType.uri:
        return Icons.link;
      case _DraftType.text:
        return Icons.text_fields;
      case _DraftType.vCard:
        return Icons.person_outline;
      case _DraftType.wifi:
        return Icons.wifi;
      case _DraftType.customMime:
        return Icons.data_object;
    }
  }
}

class WritePage extends StatefulWidget {
  const WritePage({super.key});

  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  final _formKey = GlobalKey<FormState>();

  _DraftType _type = _DraftType.uri;
  final List<_DraftRecord> _records = [];

  final _uri = TextEditingController();
  final _text = TextEditingController();
  final _language = TextEditingController(text: 'en');

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _organization = TextEditingController();
  final _jobTitle = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postalCode = TextEditingController();
  final _country = TextEditingController();
  final _note = TextEditingController();

  final _ssid = TextEditingController();
  final _wifiPassword = TextEditingController();
  final _mimeType = TextEditingController(text: 'application/octet-stream');
  final _payloadHex = TextEditingController();
  WifiSecurity _security = WifiSecurity.wpa2Personal;
  bool _obscureWifiPassword = true;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _uri,
      _text,
      _language,
      _firstName,
      _lastName,
      _organization,
      _jobTitle,
      _phone,
      _email,
      _website,
      _street,
      _city,
      _region,
      _postalCode,
      _country,
      _note,
      _ssid,
      _wifiPassword,
      _mimeType,
      _payloadHex,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WriteProvider>(
      builder: (context, provider, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            SectionCard(
              title: 'Create records and write a tag',
              subtitle: _records.isEmpty
                  ? 'Create your records, then write them to an NFC tag.'
                  : '${_records.length} record(s) · '
                        '${NdefBuilder.encodedSize(_records.map((e) => e.record).toList())} bytes',
              icon: Icons.contactless,
              child: Text(
                'Choose a record type below. Add one or more records before '
                'writing; each record is checked against the tag capacity.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Add record',
              subtitle: 'Choose the content to add to your tag message.',
              icon: Icons.edit_note,
              child: Wrap(
                runSpacing: 4,
                children: [
                  for (final type in _DraftType.values)
                    SizedBox(
                      width: double.infinity,
                      child: ListTile(
                        dense: true,
                        selected: _type == type,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: CircleAvatar(
                          radius: 17,
                          backgroundColor: _type == type
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainer,
                          foregroundColor: _type == type
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.primary,
                          child: Icon(type.icon, size: 18),
                        ),
                        title: Text(type.label),
                        trailing: _type == type
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              )
                            : Icon(
                                Icons.chevron_right,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        onTap: () {
                          setState(() => _type = type);
                          provider.clear();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Form(key: _formKey, child: _buildFormCard()),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: provider.writing ? null : _addRecord,
              icon: const Icon(Icons.add),
              label: const Text('Add record to message'),
            ),
            if (_records.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DraftRecordsCard(
                records: _records,
                onRemove: (index) {
                  setState(() => _records.removeAt(index));
                  provider.clear();
                },
              ),
            ],
            const SizedBox(height: 12),
            if (provider.writing) _WriteProgressCard(status: provider.status),
            if (provider.error != null) _WriteErrorCard(error: provider.error!),
            if (provider.result != null)
              _WriteResultCard(
                key: ObjectKey(provider.result),
                result: provider.result!,
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: provider.writing ? null : _submit,
                icon: const Icon(Icons.nfc),
                label: Text(provider.writing ? 'Writing…' : 'Write to tag'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Writing replaces the tag\'s current NDEF message. Keep the tag '
              'against the phone until verification completes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormCard() {
    switch (_type) {
      case _DraftType.uri:
        return SectionCard(
          title: 'URL or URI',
          subtitle:
              'Web links, tel:, mailto:, geo: and custom schemes '
              'are supported.',
          icon: Icons.link,
          child: TextFormField(
            controller: _uri,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.url],
            decoration: const InputDecoration(
              labelText: 'URL or URI',
              hintText: 'https://example.com',
              prefixIcon: Icon(Icons.public),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a URL or URI.'
                : null,
          ),
        );
      case _DraftType.text:
        return SectionCard(
          title: 'Plain text',
          subtitle: 'Stores text with a language code for correct rendering.',
          icon: Icons.text_fields,
          child: Column(
            children: [
              TextFormField(
                controller: _text,
                keyboardType: TextInputType.multiline,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  hintText: 'Your message',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter the text to encode.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _language,
                maxLength: 8,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Language code',
                  hintText: 'en',
                  helperText: 'ISO 639-1 code, for example en or sw.',
                ),
              ),
            ],
          ),
        );
      case _DraftType.vCard:
        return SectionCard(
          title: 'vCard contact',
          subtitle: 'Creates a text/vcard record that opens as a contact.',
          icon: Icons.person_outline,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _organization,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Organization'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobTitle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Job title'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const <String>[AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _website,
                keyboardType: TextInputType.url,
                autofillHints: const <String>[AutofillHints.url],
                decoration: const InputDecoration(
                  labelText: 'Website',
                  prefixIcon: Icon(Icons.public),
                ),
              ),
              const SizedBox(height: 4),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                maintainState: true,
                title: const Text('Address and notes'),
                children: [
                  TextFormField(
                    controller: _street,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Street'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _postalCode,
                          decoration: const InputDecoration(
                            labelText: 'Postal code',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _region,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _country,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case _DraftType.wifi:
        return SectionCard(
          title: 'Wi-Fi network',
          subtitle: 'Creates a Wi-Fi Simple Configuration record.',
          icon: Icons.wifi,
          child: Column(
            children: [
              TextFormField(
                controller: _ssid,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Network name (SSID)',
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the Wi-Fi network name.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WifiSecurity>(
                initialValue: _security,
                decoration: const InputDecoration(
                  labelText: 'Security',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
                items: [
                  for (final security in WifiSecurity.values)
                    DropdownMenuItem(
                      value: security,
                      child: Text(security.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _security = value);
                  }
                },
              ),
              if (_security.requiresPassword) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _wifiPassword,
                  obscureText: _obscureWifiPassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      tooltip: _obscureWifiPassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () {
                        setState(
                          () => _obscureWifiPassword = !_obscureWifiPassword,
                        );
                      },
                      icon: Icon(
                        _obscureWifiPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (_security.requiresPassword &&
                        (value == null || value.length < 8)) {
                      return 'WPA/WPA2 passwords need at least 8 characters.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Wi-Fi tag handling varies by phone. iPhones do not join '
                  'networks automatically from NFC tags.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      case _DraftType.customMime:
        return SectionCard(
          title: 'Custom MIME record',
          subtitle: 'Write a MIME type and raw payload bytes as hexadecimal.',
          icon: Icons.data_object,
          child: Column(
            children: [
              TextFormField(
                controller: _mimeType,
                keyboardType: TextInputType.text,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'MIME type',
                  hintText: 'application/octet-stream',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || !value.contains('/')) {
                    return 'Enter a MIME type, such as application/json.';
                  }
                  try {
                    NdefBuilder.mime(value, Uint8List(0));
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payloadHex,
                style: const TextStyle(fontFamily: 'monospace'),
                keyboardType: TextInputType.multiline,
                minLines: 3,
                maxLines: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp('[0-9a-fA-F\\s:\\-]'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Payload (hexadecimal)',
                  hintText: '48 65 6C 6C 6F',
                  helperText:
                      'Enter bytes separated by spaces, colons or dashes.',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter at least one payload byte.';
                  }
                  try {
                    hexToBytes(value);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
            ],
          ),
        );
    }
  }

  void _addRecord() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      final record = _buildRecord();
      setState(() {
        _records.add(_DraftRecord(type: _type, record: record));
        _clearCurrentDraft();
      });
      context.read<WriteProvider>().clear();
    } on FormatException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, isError: true);
      }
    }
  }

  void _clearCurrentDraft() {
    switch (_type) {
      case _DraftType.uri:
        _uri.clear();
        break;
      case _DraftType.text:
        _text.clear();
        break;
      case _DraftType.vCard:
        for (final controller in <TextEditingController>[
          _firstName,
          _lastName,
          _organization,
          _jobTitle,
          _phone,
          _email,
          _website,
          _street,
          _city,
          _region,
          _postalCode,
          _country,
          _note,
        ]) {
          controller.clear();
        }
        break;
      case _DraftType.wifi:
        _ssid.clear();
        _wifiPassword.clear();
        break;
      case _DraftType.customMime:
        _payloadHex.clear();
        break;
    }
  }

  Future<void> _submit() async {
    var records = _records.map((draft) => draft.record).toList(growable: false);
    if (records.isEmpty) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return;
      }
      try {
        records = [_buildRecord()];
      } on FormatException catch (error) {
        if (mounted) {
          showAppSnackBar(context, error.message, isError: true);
        }
        return;
      }
    }
    await context.read<WriteProvider>().write(records);
  }

  ndef.NDEFRecord _buildRecord() {
    switch (_type) {
      case _DraftType.uri:
        return NdefBuilder.uri(_uri.text);
      case _DraftType.text:
        return NdefBuilder.text(_text.text, language: _language.text);
      case _DraftType.vCard:
        return NdefBuilder.vCard(
          VCardData(
            firstName: _firstName.text,
            lastName: _lastName.text,
            organization: _organization.text,
            title: _jobTitle.text,
            phone: _phone.text,
            email: _email.text,
            website: _website.text,
            street: _street.text,
            city: _city.text,
            region: _region.text,
            postalCode: _postalCode.text,
            country: _country.text,
            note: _note.text,
          ),
        );
      case _DraftType.wifi:
        return NdefBuilder.wifi(
          WifiCredentials(
            ssid: _ssid.text,
            password: _wifiPassword.text,
            security: _security,
          ),
        );
      case _DraftType.customMime:
        return NdefBuilder.mime(_mimeType.text, hexToBytes(_payloadHex.text));
    }
  }
}

class _WriteProgressCard extends StatelessWidget {
  const _WriteProgressCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.isEmpty ? 'Working…' : status,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _DraftRecordsCard extends StatelessWidget {
  const _DraftRecordsCard({required this.records, required this.onRemove});

  final List<_DraftRecord> records;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      title: 'Message records',
      subtitle: 'Records are written in this order.',
      icon: Icons.list_alt,
      child: Column(
        children: [
          for (var index = 0; index < records.length; index++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 17, child: Text('${index + 1}')),
              title: Text(records[index].type.label),
              subtitle: Text(
                NdefInspector.inspect([records[index].record]).single.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              trailing: IconButton(
                tooltip: 'Remove record',
                onPressed: () => onRemove(index),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      ),
    );
  }
}

class _WriteErrorCard extends StatelessWidget {
  const _WriteErrorCard({required this.error});

  final NfcException error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error.message,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
            if (error.hint != null) ...[
              const SizedBox(height: 8),
              Text(
                error.hint!,
                style: TextStyle(
                  color: scheme.onErrorContainer.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WriteResultCard extends StatefulWidget {
  const _WriteResultCard({super.key, required this.result});

  final WriteResult result;

  @override
  State<_WriteResultCard> createState() => _WriteResultCardState();
}

class _WriteResultCardState extends State<_WriteResultCard> {
  bool _saving = false;
  bool _saved = false;
  bool _locking = false;
  bool _locked = false;

  Future<void> _save() async {
    if (_saving || _saved) {
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<SavedTagRepository>().save(widget.result.scan);
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saved = true;
      });
      showAppSnackBar(context, 'Tag saved to your library.');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not save tag: $error', isError: true);
    }
  }

  Future<void> _lock() async {
    if (_locking || _locked) {
      return;
    }
    setState(() => _locking = true);
    final locked = await showLockTagFlow(
      context,
      expectedUid: widget.result.scan.formattedUid,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _locking = false;
      _locked = locked;
    });
    if (!locked) {
      return;
    }
    try {
      await context.read<SavedTagRepository>().markWriteProtected(
        widget.result.scan.formattedUid,
      );
    } on Object catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Tag locked, but its saved status could not be updated: $error',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = widget.result.verified;
    final color = success ? scheme.primary : scheme.tertiary;
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle_outline : Icons.info_outline,
                  color: color,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success ? 'Write verified' : 'Write completed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Tag: ${widget.result.scan.formattedUid}'),
            Text('Payload: ${formatBytes(widget.result.bytesWritten)}'),
            if (widget.result.verifyError != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.result.verifyError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!_saved)
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save tag'),
                  ),
                if (_saved && !_locked)
                  FilledButton.tonalIcon(
                    onPressed: _locking ? null : _lock,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      _locking ? 'Waiting for tag…' : 'Lock with password',
                    ),
                  ),
                if (_saved)
                  Chip(
                    avatar: Icon(
                      _locked ? Icons.lock : Icons.bookmark,
                      size: 16,
                    ),
                    label: Text(_locked ? 'Saved and locked' : 'Saved'),
                  ),
              ],
            ),
            if (_saved && !_locked) ...[
              const SizedBox(height: 8),
              Text(
                'Locking asks you to hold the same tag again. The tag stays '
                'readable, but rewriting it will require the password.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
