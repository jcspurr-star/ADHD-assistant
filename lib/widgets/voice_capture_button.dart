import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCaptureButton extends StatefulWidget {
  const VoiceCaptureButton({
    super.key,
    required this.controller,
    this.tooltip = 'Voice capture',
    this.autoStart = false,
  });

  final TextEditingController controller;
  final String tooltip;
  final bool autoStart;

  @override
  State<VoiceCaptureButton> createState() => _VoiceCaptureButtonState();
}

class _VoiceCaptureButtonState extends State<VoiceCaptureButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _initializing = false;
  bool _listening = false;
  String _capturedPrefix = '';

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleListening();
      });
    }
  }

  @override
  void didUpdateWidget(covariant VoiceCaptureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoStart && !oldWidget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggleListening();
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_initializing) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() => _initializing = true);
    _available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _listening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _initializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice capture unavailable: ${error.errorMsg}'),
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _initializing = false);
    if (!_available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice capture is unavailable or microphone access was denied.',
          ),
        ),
      );
      return;
    }

    _capturedPrefix = widget.controller.text.trimRight();
    if (_capturedPrefix.isNotEmpty) _capturedPrefix += ' ';
    await _speech.listen(onResult: _onSpeechResult);
    if (mounted) setState(() => _listening = true);
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    final text = '$_capturedPrefix$words'.trimRight();
    widget.controller.value = widget.controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _listening ? 'Stop voice capture' : widget.tooltip,
      color: _listening ? Theme.of(context).colorScheme.primary : null,
      icon: _initializing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_listening ? Icons.mic : Icons.mic_none),
      onPressed: _toggleListening,
    );
  }
}
