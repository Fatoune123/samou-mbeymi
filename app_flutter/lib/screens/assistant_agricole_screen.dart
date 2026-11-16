import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AssistantAgricoleScreen extends StatefulWidget {
  /// Permet au mode entièrement vocal d'ouvrir les rubriques de l'application.
  /// Les destinations correspondent aux index déjà utilisés par le tableau de bord.
  final ValueChanged<int>? onNavigate;
  const AssistantAgricoleScreen({super.key, this.onNavigate});

  @override
  State<AssistantAgricoleScreen> createState() => _AssistantAgricoleScreenState();
}

class _AssistantAgricoleScreenState extends State<AssistantAgricoleScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  final BytesBuilder _audioBytes = BytesBuilder(copy: false);
  final FlutterTts _tts = FlutterTts();
  final List<_ChatMessage> _messages = [];

  static const Map<String, String> _languages = {
    'fr-FR': 'Français',
    'wo-SN': 'Wolof',
    'ff': 'Pulaar',
    'srr': 'Sérère',
    'dyo': 'Joola',
    'mnk': 'Mandinka',
    'snk': 'Soninké',
  };

  String _language = 'fr-FR';
  String _mode = 'mixte';
  String _recognizedText = '';
  String? _error;
  bool _sending = false;
  bool _recordingReady = false;
  bool _listening = false;
  bool _ttsReady = false;
  bool _autoSpeak = true;


  bool get _voiceMode => _mode == 'vocal' || _mode == 'integral';
  bool get _canUseMicrophone => _mode != 'ecrit';
  bool get _textMode => _mode == 'ecrit' || _mode == 'mixte';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  Future<void> _initializeSpeech() async {
    try {
      final permitted = await _audioRecorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _recordingReady = permitted;
        _error = permitted ? null : 'Autorisez le microphone dans les paramètres Android.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _recordingReady = false;
        _error = 'Initialisation du microphone impossible : $e';
      });
    }
  }

  Future<void> _initializeTts() async {
    try {
      await _tts.setSpeechRate(0.43);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() {
        if (mounted && _mode == 'integral' && !_sending && !_listening) {
          Future<void>.delayed(const Duration(milliseconds: 350), _startListening);
        }
      });
      if (mounted) setState(() => _ttsReady = true);
    } catch (_) {
      if (mounted) setState(() => _ttsReady = false);
    }
  }

  String get _ttsLocale {
    // Ne pas substituer silencieusement une langue nationale par le français.
    switch (_language) {
      case 'fr-FR': return 'fr-FR';
      case 'wo-SN': return 'wo-SN';
      case 'ff': return 'ff';
      case 'srr': return 'srr';
      case 'dyo': return 'dyo';
      case 'mnk': return 'mnk';
      case 'snk': return 'snk';
      default: return _language;
    }
  }

  Future<void> _startListening() async {
    if (_mode == 'ecrit' || _sending || _listening) return;
    if (!_recordingReady) await _initializeSpeech();
    if (!_recordingReady) {
      setState(() => _error = 'Microphone indisponible. Vérifiez les autorisations de l’application.');
      return;
    }
    try {
      _audioBytes.clear();
      await _audioSubscription?.cancel();
      final stream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ));
      _audioSubscription = stream.listen((chunk) => _audioBytes.add(chunk));
      if (!mounted) return;
      setState(() {
        _error = null;
        _recognizedText = '';
        _listening = true;
      });
    } catch (e) {
      if (mounted) setState(() {
        _listening = false;
        _error = 'Impossible de démarrer le microphone : $e';
      });
    }
  }

  Uint8List _pcmToWav(Uint8List pcm, {int sampleRate = 16000}) {
    final dataSize = pcm.length;
    final bytes = ByteData(44 + dataSize);
    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);
    for (var i = 0; i < dataSize; i++) {
      bytes.setUint8(44 + i, pcm[i]);
    }
    return bytes.buffer.asUint8List();
  }

  Future<void> _stopListening() async {
    try {
      await _audioRecorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      final pcm = _audioBytes.takeBytes();
      if (mounted) setState(() => _listening = false);
      if (pcm.length < 8000) {
        if (mounted) setState(() => _error = 'Enregistrement trop court. Parlez pendant au moins une seconde.');
        return;
      }
      if (mounted) setState(() => _sending = true);
      final wav = _pcmToWav(pcm);
      final transcript = await _api.transcrireAudioAssistant(wavBytes: wav, langue: _language);
      if (!mounted) return;
      setState(() {
        _recognizedText = transcript;
        _sending = false;
      });
      await _sendQuestion(transcript);
    } catch (e) {
      if (mounted) setState(() => _error = 'Transcription impossible : $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendTypedQuestion() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;
    _questionController.clear();
    await _sendQuestion(question);
  }

  Future<void> _sendQuestion(String question) async {
    if (question.trim().isEmpty || _sending) return;
    final cleanQuestion = question.trim();
    setState(() {
      _messages.add(_ChatMessage(text: cleanQuestion, isUser: true));
      _sending = true;
      _error = null;
    });
    _scrollToBottom();

    // Navigation vocale uniquement sur des formulations explicites, afin de ne
    // pas confondre une question agricole contenant « récolte » ou « maladie ».
    if (_mode == 'integral' && widget.onNavigate != null) {
      final destination = _explicitNavigation(cleanQuestion);
      if (destination != null) {
        final message = 'D’accord. J’ouvre la rubrique demandée.';
        setState(() {
          _messages.add(_ChatMessage(text: message, isUser: false));
          _sending = false;
        });
        await _speak(message);
        if (mounted) widget.onNavigate!(destination);
        return;
      }
    }

    try {
      final result = await _api.conseillerAgricole(
        question: cleanQuestion,
        langue: _language,
      );
      if (!mounted) return;
      final answer = (result['answer'] ?? result['reponse'] ?? '').toString().trim();
      final safeAnswer = answer.isEmpty
          ? 'Je n’ai pas reçu de réponse. Veuillez réessayer.'
          : answer;
      setState(() => _messages.add(_ChatMessage(text: safeAnswer, isUser: false)));
      if (_voiceMode || (_mode == 'mixte' && _autoSpeak)) {
        await _speak(safeAnswer);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
        if (_mode == 'integral') {
          Future<void>.delayed(const Duration(milliseconds: 350), _startListening);
        }
      }
    }
  }

  int? _explicitNavigation(String text) {
    final q = text.toLowerCase().replaceAll('’', "'").replaceAll('‘', "'");
    final explicitOpen = q.contains('ouvre ') || q.contains('ouvrir ') ||
        q.contains('va à ') || q.contains('aller à ') ||
        q.contains('amène-moi ') || q.contains('affiche ');
    if (!explicitOpen) return null;
    if (q.contains('récolte') || q.contains('recolte')) return 1;
    if (q.contains('perte')) return 2;
    if (q.contains('scanner')) return 3;
    if (q.contains('profil') || q.contains('compte')) return 5;
    if (q.contains('tableau de bord') || q.contains('accueil')) return 0;
    return null;
  }

  Future<String?> _resolveTtsLocale() async {
    // Le moteur Android expose parfois fr-FR, fr_FR ou fr-CA au lieu de fr-FR.
    // On choisit une variante française réellement installée, sans basculer
    // silencieusement vers une autre langue.
    final wanted = _ttsLocale.toLowerCase().replaceAll('_', '-');
    try {
      final dynamic installed = await _tts.getLanguages;
      if (installed is List) {
        final locales = installed.map((e) => e.toString()).toList();
        for (final locale in locales) {
          if (locale.toLowerCase().replaceAll('_', '-') == wanted) return locale;
        }
        if (_language.toLowerCase().startsWith('fr')) {
          for (final locale in locales) {
            if (locale.toLowerCase().replaceAll('_', '-').startsWith('fr-')) {
              return locale;
            }
          }
          for (final locale in locales) {
            if (locale.toLowerCase() == 'fr') return locale;
          }
        }
      }
    } catch (_) {
      // Certains moteurs TTS ne permettent pas d'énumérer leurs langues.
    }

    final candidates = <String>[
      _ttsLocale,
      if (_language.toLowerCase().startsWith('fr')) ...['fr-FR', 'fr_FR', 'fr'],
    ];
    for (final locale in candidates.toSet()) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true || available == 1) return locale;
      } catch (_) {
        // Tester la variante suivante.
      }
    }
    return null;
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady) {
      if (mounted) setState(() => _error = 'La synthèse vocale n’est pas initialisée sur cet appareil.');
      return;
    }
    try {
      final locale = await _resolveTtsLocale();
      if (locale == null) {
        if (mounted) setState(() => _error =
            'Aucune voix ${_languages[_language]} compatible n’est installée. Installez une voix française dans les paramètres de synthèse vocale Android. La réponse reste disponible à l’écran.');
        return;
      }
      final result = await _tts.setLanguage(locale);
      if (result == false || result == 0) {
        throw StateError('Le moteur vocal a refusé la langue $locale');
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      if (mounted) setState(() => _error = 'Lecture vocale impossible pour ${_languages[_language]} : $e');
    }
  }

  void _setMode(String mode) {
    if (_listening) _stopListening();
    _tts.stop();
    setState(() {
      _mode = mode;
      _listening = false;
      _error = null;
    });
    if (mode == 'integral' && _messages.isEmpty) {
      _speak('Assistant agricole prêt. Vous pouvez poser une question ou demander une rubrique.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _tts.stop();
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant agricole SAMOU MBEYMI', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primary.withValues(alpha: .10)),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .06), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choisissez votre mode d’utilisation',
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _modeChip('ecrit', 'Écrit', Icons.keyboard_alt_outlined),
                      _modeChip('vocal', 'Vocal', Icons.mic_none_rounded),
                      _modeChip('mixte', 'Mixte', Icons.record_voice_over_rounded),
                      _modeChip('integral', 'Entièrement vocal', Icons.hearing_rounded),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _language,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Langue de l’assistant',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _languages.entries.map((entry) => DropdownMenuItem(
                      value: entry.key, child: Text(entry.value),
                    )).toList(),
                    onChanged: _sending || _listening ? null : (value) {
                      if (value != null) setState(() {
                        _language = value;
                        _error = null;
                      });
                    },
                  ),
                  if (_mode == 'mixte')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Lire automatiquement les réponses'),
                      value: _autoSpeak,
                      onChanged: (value) => setState(() => _autoSpeak = value),
                    ),
                  if (_mode == 'integral')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Dites votre question. Pour naviguer, dites par exemple : « Ouvre les récoltes ». ',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.agriculture_rounded, size: 48,
                            color: AppColors.primary.withValues(alpha: .55)),
                        const SizedBox(height: 12),
                        const Text('Comment puis-je vous aider ?',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 8),
                        const Text('Exemple : Comment conserver mes tomates après la récolte ?',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.inkSoft)),
                      ]),
                    ))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _messages.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('L’assistant prépare une réponse…',
                                style: TextStyle(color: AppColors.inkSoft)),
                          );
                        }
                        final message = _messages[index];
                        return Align(
                          alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 340),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: message.isUser ? AppColors.primary : AppColors.bg,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(message.text, style: TextStyle(
                                  color: message.isUser ? Colors.white : AppColors.ink,
                                  height: 1.4,
                                )),
                                if (!message.isUser && (_voiceMode || _mode == 'mixte'))
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      tooltip: 'Écouter la réponse',
                                      onPressed: () => _speak(message.text),
                                      icon: const Icon(Icons.volume_up_rounded),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_recognizedText.isNotEmpty && _listening)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text('Reconnu : $_recognizedText',
                    style: const TextStyle(color: AppColors.inkSoft)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.loss)),
              ),
            if (_canUseMicrophone)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : (_listening ? _stopListening : _startListening),
                    icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_rounded, size: 26),
                    label: Text(_listening ? 'Arrêter l’écoute' : 'Parler à l’assistant'),
                  ),
                ),
              ),
            if (_textMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: TextField(
                      controller: _questionController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendTypedQuestion(),
                      decoration: const InputDecoration(
                        hintText: 'Écrivez votre question agricole…',
                        border: OutlineInputBorder(),
                      ),
                    )),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _sending ? null : _sendTypedQuestion,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 52), padding: EdgeInsets.zero,
                      ),
                      child: _sending
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                'La reconnaissance audio passe par le serveur pour les langues configurées. La lecture vocale dépend des voix installées sur votre appareil. Les conseils agricoles restent indicatifs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = _mode == value;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 17, color: selected ? Colors.white : AppColors.primary),
      label: Text(label),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
      onSelected: _sending ? null : (_) => _setMode(value),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}
