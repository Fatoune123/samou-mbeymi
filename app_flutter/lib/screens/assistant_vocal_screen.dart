import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme.dart';
import '../services/api_service.dart';

/// Assistant agricole : conversation agricole et commandes vocales facultatives.
/// Les commandes vocales ne modifient aucune donnée métier sans action explicite.
class AssistantVocalScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const AssistantVocalScreen({super.key, required this.onNavigate});

  @override
  State<AssistantVocalScreen> createState() => _AssistantVocalScreenState();
}

class _AssistantVocalScreenState extends State<AssistantVocalScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSubscription;
  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  bool _remoteRecording = false;
  Uint8List? _lastWavRecording;
  final FlutterTts _tts = FlutterTts();
  final ApiService _api = ApiService();
  final TextEditingController _questionController = TextEditingController();
  bool _speechAvailable = false;
  bool _listening = false;
  bool _busy = false;
  String _language = 'fr-FR';
  String _recognized = '';
  String _answer = 'Bonjour ! Appuyez sur le microphone et donnez une commande.';
  String? _error;

  static const Map<String, String> _speechLocales = {
    'fr-FR': 'fr_FR', 'wo-SN': 'wo_SN', 'ff': 'ff_SN',
    'srr': 'srr_SN', 'dyo': 'dyo_SN', 'mnk': 'mnk_SN',
    'snk': 'snk_SN', 'en-US': 'en_US',
  };
  String get _localeId => _speechLocales[_language] ?? 'fr_FR';
  String get _ttsLocale => _language == 'ff' ? 'ff-SN' : _language == 'srr' ? 'srr-SN' :
      _language == 'dyo' ? 'dyo-SN' : _language == 'mnk' ? 'mnk-SN' :
      _language == 'snk' ? 'snk-SN' : _language;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _tts.setSpeechRate(0.43);
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('fr-FR');
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = 'Reconnaissance vocale : ${error.errorMsg}';
            _listening = false;
          });
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
      if (!available) {
        setState(() => _error = 'La reconnaissance vocale est indisponible. Vérifiez le microphone et le service vocal de votre appareil.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de démarrer les services vocaux sur cet appareil.');
    }
  }

  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;
    if (_listening) await _speech.stop();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _language = value;
      _error = null;
    });
  }

  Future<void> _toggleListening() async {
    if (_busy) return;
    if (_remoteRecording) {
      await _stopRemoteRecording();
      return;
    }
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speechAvailable) {
      await _initialize();
      if (!_speechAvailable) {
        await _startRemoteRecording();
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
      _recognized = '';
    });
    try {
      final locales = await _speech.locales();
      final requestedId = _localeId.toLowerCase().replaceAll('-', '_');
      final requestedLanguage = requestedId.split('_').first;
      // Certains téléphones exposent la même langue avec une région différente
      // (ex. fr_FR au lieu de fr_CA). On accepte uniquement la même langue,
      // jamais une substitution silencieuse vers une autre langue.
      final requested = locales.where((l) {
        final installedId = l.localeId.toLowerCase().replaceAll('-', '_');
        return installedId == requestedId ||
            installedId.split('_').first == requestedLanguage;
      }).toList();
      String? selectedLocale;
      if (requested.isNotEmpty) {
        selectedLocale = requested.first.localeId;
      } else if (_language.toLowerCase().startsWith('fr')) {
        // Certains services Android n'exposent pas leur liste de locales.
        // On tente alors le code français standard au lieu de bloquer le micro.
        selectedLocale = 'fr_FR';
      }
      if (selectedLocale == null) {
        await _startRemoteRecording();
        return;
      }
      await _speech.listen(
        localeId: selectedLocale,
        listenFor: const Duration(seconds: 20),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _recognized = result.recognizedWords);
          if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
            _handleCommand(result.recognizedWords);
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de démarrer l’écoute. Vérifiez les autorisations du microphone.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  Future<void> _startRemoteRecording() async {
    try {
      final permitted = await _audioRecorder.hasPermission();
      if (!permitted) {
        if (mounted) setState(() => _error = 'Autorisez le microphone dans les paramètres de votre téléphone.');
        return;
      }
      _pcmBuffer.clear();
      final stream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      _audioSubscription = stream.listen(
        _pcmBuffer.add,
        onError: (Object error) {
          if (mounted) setState(() => _error = 'Erreur pendant l’enregistrement : $error');
        },
      );
      if (!mounted) return;
      setState(() {
        _remoteRecording = true;
        _listening = true;
        _busy = false;
        _error = 'Parlez maintenant. Appuyez de nouveau sur le microphone pour terminer.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _remoteRecording = false;
          _listening = false;
          _error = 'Impossible d’enregistrer : vérifiez la permission du microphone. $e';
        });
      }
    }
  }

  Future<void> _stopRemoteRecording() async {
    if (!_remoteRecording || _busy) return;
    setState(() {
      _busy = true;
      _listening = false;
      _error = 'Transcription vocale en cours…';
    });
    try {
      await _audioRecorder.stop();
      await _audioSubscription?.cancel();
      _audioSubscription = null;
      final pcm = _pcmBuffer.takeBytes();
      if (pcm.length < 16000) {
        throw ApiException('Enregistrement trop court. Parlez un peu plus longtemps puis réessayez.');
      }
      final wav = _pcmToWav(pcm, sampleRate: 16000);
      _lastWavRecording = wav;
      final transcript = await _api.transcrireAudioAssistant(
        wavBytes: wav,
        langue: _language,
      );
      if (!mounted) return;
      setState(() {
        _recognized = transcript;
        _lastWavRecording = null;
        _remoteRecording = false;
        _busy = false;
        _error = null;
      });
      await _handleCommand(transcript);
    } catch (e) {
      if (mounted) {
        setState(() {
          _remoteRecording = false;
          _error = 'Transcription impossible : $e. Vous pouvez réessayer ou saisir la question.';
        });
      }
    } finally {
      if (mounted) setState(() {
        _busy = false;
        _listening = false;
      });
    }
  }

  Future<void> _retryRemoteTranscription() async {
    final wav = _lastWavRecording;
    if (wav == null || _busy) return;
    setState(() {
      _busy = true;
      _error = 'Nouvelle tentative de transcription…';
    });
    try {
      final transcript = await _api.transcrireAudioAssistant(
        wavBytes: wav,
        langue: _language,
      );
      if (!mounted) return;
      setState(() {
        _recognized = transcript;
        _lastWavRecording = null;
        _busy = false;
        _error = null;
      });
      await _handleCommand(transcript);
    } catch (e) {
      if (mounted) setState(() => _error = 'Le service vocal ne répond toujours pas : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Uint8List _pcmToWav(Uint8List pcm, {required int sampleRate}) {
    final header = ByteData(44);
    void writeTag(int offset, String tag) {
      for (var i = 0; i < tag.length; i++) {
        header.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }
    writeTag(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    writeTag(8, 'WAVE');
    writeTag(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    writeTag(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
  }

  Future<void> _handleCommand(String words) async {
    final text = words.toLowerCase().trim();
    String response;
    int? destination;

    if (_containsAny(text, ['récolte', 'recolte', 'harvest', 'ngóob'])) {
      response = 'J’ouvre la section Récoltes.';
      destination = 1;
    } else if (_containsAny(text, ['perte', 'pertes', 'loss', 'ñàkk'])) {
      response = 'J’ouvre la section Pertes.';
      destination = 2;
    } else if (_containsAny(text, ['scanner', 'maladie', 'photo', 'scan'])) {
      response = 'J’ouvre le scanner agricole.';
      destination = 3;
    } else if (_containsAny(text, ['carte', 'localisation', 'position', 'marché', 'marche', 'gps'])) {
      response = 'J’ouvre la carte et la localisation.';
      destination = 4;
    } else if (_containsAny(text, ['profil', 'compte'])) {
      response = 'J’ouvre votre profil.';
      destination = 5;
    } else if (_containsAny(text, ['bonjour', 'salut', 'hello', 'salaam', 'asalaam'])) {
      response = _language == 'wo-SN'
          ? 'Salaam maalekum. Lan nga bëgg ma defal la ?'
          : 'Bonjour ! Je peux ouvrir les récoltes, les pertes, le scanner, la carte ou votre profil.';
    } else if (_containsAny(text, ['aide', 'que peux-tu faire', 'commandes'])) {
      response = 'Vous pouvez dire : ouvre les récoltes, ouvre les pertes, ouvre le scanner, ouvre la carte ou ouvre mon profil.';
    } else {
      await _askGemini(words);
      return;
    }

    if (!mounted) return;
    setState(() => _answer = response);
    await _speakAnswer(response);
    if (destination != null && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        widget.onNavigate(destination);
        Navigator.of(context).pop();
      }
    }
  }

  Future<String?> _resolveTtsLocale() async {
    final wanted = _ttsLocale.toLowerCase().replaceAll('_', '-');
    try {
      final dynamic installed = await _tts.getLanguages;
      if (installed is List) {
        final locales = installed.map((e) => e.toString()).toList();
        for (final locale in locales) {
          if (locale.toLowerCase().replaceAll('_', '-') == wanted) return locale;
        }
        // Certains moteurs exposent seulement le code de langue (ex. "wo")
        // ou une autre région (ex. "fr-CA"). On accepte uniquement la même langue.
        final languageCode = wanted.split('-').first;
        for (final locale in locales) {
          final normalized = locale.toLowerCase().replaceAll('_', '-');
          if (normalized == languageCode || normalized.startsWith('$languageCode-')) {
            return locale;
          }
        }
      }
    } catch (_) {}
    final languageCode = _language.toLowerCase().split(RegExp('[-_]')).first;
    final candidates = <String>[
      _ttsLocale,
      languageCode,
      '${languageCode}_SN',
      '${languageCode}-SN',
      if (languageCode == 'fr') ...['fr-FR', 'fr_FR', 'fr'],
    ];
    for (final locale in candidates.toSet()) {
      try {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == true || available == 1) return locale;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _speakAnswer(String text) async {
    try {
      final locale = await _resolveTtsLocale();
      if (locale == null) {
        if (mounted) setState(() => _error =
            'Aucune voix installée pour cette langue sur le téléphone. Installez une voix compatible dans les paramètres de synthèse vocale Android. La réponse ne sera pas remplacée par une autre langue.');
        return;
      }
      final result = await _tts.setLanguage(locale);
      if (result == false || result == 0) {
        throw StateError('Langue vocale refusée par le moteur');
      }
      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Impossible de prononcer cette langue avec le moteur vocal de cet appareil. La réponse reste affichée en texte.');
      }
    }
  }

  Future<void> _askGemini(String question) async {
    if (question.trim().isEmpty || _busy) return;
    if (mounted) setState(() { _busy = true; _error = null; });
    try {
      final result = await _api.conseillerAgricole(
        question: question.trim(),
        langue: _language,
      );
      final response = (result['answer'] ?? result['reponse'] ?? '').toString().trim();
      if (response.isEmpty) throw ApiException('Gemini n’a pas retourné de réponse.');
      if (!mounted) return;
      setState(() => _answer = response);
      await _speakAnswer(response);
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de contacter le conseiller : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendTypedQuestion() async {
    final text = _questionController.text.trim();
    if (text.isEmpty || _busy) return;
    _questionController.clear();
    setState(() => _recognized = text);
    await _askGemini(text);
  }

  bool _containsAny(String text, List<String> terms) => terms.any(text.contains);

  @override
  void dispose() {
    _speech.stop();
    _audioSubscription?.cancel();
    _audioRecorder.dispose();
    _tts.stop();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant agricole')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Icon(Icons.record_voice_over_rounded, size: 52, color: AppColors.accent),
                  SizedBox(height: 12),
                  Text('SAMOU MBEY — ASSISTANT AGRICOLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  SizedBox(height: 8),
                  Text('Posez vos questions agricoles par la voix ou par écrit. Je réponds uniquement sur les sujets agricoles.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Langue de l’assistant', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'fr-FR', child: Text('Français')),
                DropdownMenuItem(value: 'wo-SN', child: Text('Wolof')),
                DropdownMenuItem(value: 'ff', child: Text('Pulaar (Peul)')),
                DropdownMenuItem(value: 'srr', child: Text('Sérère')),
                DropdownMenuItem(value: 'dyo', child: Text('Joola (Diola)')),
                DropdownMenuItem(value: 'mnk', child: Text('Mandinka')),
                DropdownMenuItem(value: 'snk', child: Text('Soninké')),
                DropdownMenuItem(value: 'en-US', child: Text('English')),
              ],
              onChanged: _changeLanguage,
            ),
            const SizedBox(height: 22),
            Center(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: _listening ? 116 : 100,
                    height: _listening ? 116 : 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening ? AppColors.loss.withValues(alpha: .12) : AppColors.primary.withValues(alpha: .10),
                      border: Border.all(color: _listening ? AppColors.loss : AppColors.primary, width: 2),
                    ),
                    child: IconButton(
                      tooltip: _listening ? 'Arrêter l’écoute' : 'Poser une question agricole',
                      iconSize: 42,
                      onPressed: _busy ? null : _toggleListening,
                      icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded, color: _listening ? AppColors.loss : AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_busy ? 'Préparation du microphone…' : _listening ? 'Je vous écoute…' : 'Appuyez ici pour poser une question agricole', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _InfoCard(title: 'Ce que j’ai entendu', text: _recognized.isEmpty ? 'Votre commande apparaîtra ici.' : _recognized, icon: Icons.hearing_rounded),
            const SizedBox(height: 12),
            _InfoCard(title: 'Réponse de Gemini', text: _answer, icon: Icons.chat_bubble_outline_rounded),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTypedQuestion(),
              decoration: InputDecoration(
                hintText: 'Ou écrivez votre question agricole…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Envoyer à Gemini',
                  onPressed: _busy ? null : _sendTypedQuestion,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.loss.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.loss),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_error!, style: const TextStyle(fontSize: 13)),
                    if (_lastWavRecording != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _busy ? null : _retryRemoteTranscription,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Réessayer avec le même enregistrement'),
                      ),
                    ],
                  ])),
                ]),
              ),
            ],
            const SizedBox(height: 18),
            const Text('Exemples de navigation vocale', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            const _CommandExample(text: '« Ouvre les récoltes »'),
            const _CommandExample(text: '« Ouvre les pertes »'),
            const _CommandExample(text: '« Ouvre le scanner »'),
            const _CommandExample(text: '« Ouvre la carte »'),
            const _CommandExample(text: '« Ouvre mon profil »'),
            const SizedBox(height: 12),
            const Text('La reconnaissance et la prononciation de chaque langue dépendent des moteurs installés sur l’appareil. Si une voix locale n’est pas disponible, la réponse reste affichée en texte.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;
  const _InfoCard({required this.title, required this.text, required this.icon});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(text),
            ])),
          ]),
        ),
      );
}

class _CommandExample extends StatelessWidget {
  final String text;
  const _CommandExample({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text),
        ]),
      );
}
