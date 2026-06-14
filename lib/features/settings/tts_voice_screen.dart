import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'reading_prefs_controller.dart';

/// A read-aloud voice in a single locale.
class _Voice {
  const _Voice(this.name, this.locale);
  final String name;
  final String locale;
}

/// Lets the user pick a text-to-speech voice from those installed on the
/// device. Tapping a voice selects it and speaks a short preview.
class TtsVoiceScreen extends ConsumerStatefulWidget {
  const TtsVoiceScreen({super.key});

  @override
  ConsumerState<TtsVoiceScreen> createState() => _TtsVoiceScreenState();
}

class _TtsVoiceScreenState extends ConsumerState<TtsVoiceScreen> {
  final FlutterTts _tts = FlutterTts();
  List<_Voice>? _voices;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _tts.getVoices as List<dynamic>?;
      final voices = <_Voice>[];
      for (final v in raw ?? const []) {
        if (v is! Map) continue;
        final name = v['name']?.toString();
        final locale = v['locale']?.toString();
        if (name == null || name.isEmpty || locale == null || locale.isEmpty) {
          continue;
        }
        voices.add(_Voice(name, locale));
      }
      voices.sort((a, b) {
        final c = a.locale.toLowerCase().compareTo(b.locale.toLowerCase());
        return c != 0 ? c : a.name.compareTo(b.name);
      });
      if (mounted) setState(() => _voices = voices);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _preview(_Voice v) async {
    try {
      await _tts.stop();
      await _tts.setVoice({'name': v.name, 'locale': v.locale});
      await _tts.speak('The quick brown fox jumps over the lazy dog.');
    } catch (_) {
      // Preview is best-effort; selection still persists.
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(readingPrefsProvider.select((p) => p.ttsVoiceName));
    final c = ref.read(readingPrefsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Read-aloud voice')),
      body: _buildBody(c, selected),
    );
  }

  Widget _buildBody(ReadingPrefsController c, String? selected) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Could not list voices on this device. Read-aloud will use the '
          'system default voice.\n\n$_error',
        ),
      );
    }
    final voices = _voices;
    if (voices == null) {
      return const Center(child: CircularProgressIndicator());
    }

    String? lastLocale;
    final children = <Widget>[
      ListTile(
        leading: Icon(selected == null ? Icons.check : Icons.smartphone,
            color: selected == null ? Theme.of(context).colorScheme.primary : null),
        title: const Text('Device default'),
        subtitle: const Text('Use whatever voice your device is set to'),
        selected: selected == null,
        onTap: () => c.setTtsVoice(null, null),
      ),
      const Divider(height: 1),
    ];
    for (final v in voices) {
      if (v.locale != lastLocale) {
        lastLocale = v.locale;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            v.locale,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ));
      }
      final isSelected = v.name == selected;
      children.add(ListTile(
        leading: isSelected
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
            : const SizedBox(width: 24),
        title: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: isSelected,
        trailing: IconButton(
          tooltip: 'Preview voice',
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () => _preview(v),
        ),
        onTap: () {
          c.setTtsVoice(v.name, v.locale);
          _preview(v);
        },
      ));
    }
    return ListView(children: children);
  }
}
