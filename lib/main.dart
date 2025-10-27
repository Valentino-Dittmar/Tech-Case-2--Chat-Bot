import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // for the api call
import 'package:speech_to_text/speech_to_text.dart' as stt; // speech to text
import 'package:flutter_tts/flutter_tts.dart'; // text to speech
import 'package:flutter_dotenv/flutter_dotenv.dart'; // to load the .env file

void main() async {

  await dotenv.load(fileName: '.env');
  runApp(const MaterialApp(home: VoiceChat()));
}

class VoiceChat extends StatefulWidget {
  const VoiceChat({super.key});
  @override
  State<VoiceChat> createState() => _VoiceChatState();
}

class _VoiceChatState extends State<VoiceChat> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _controller = TextEditingController(); // gives me power over the input/textbox

  final List<Map<String, String>> _messages = [];
  bool _listening = false;

  Future<void> _listen() async {
    if (!_listening) {
      await _speech.stop(); // reset the old session because it types the old text in from memory
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _listening = true;
          _controller.clear();
        });
        await _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
        );
      }
    } else {
      await _speech.stop();
      setState(() => _listening = false);
    }
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.insert(0, {'role': 'User', 'text': text});
      _controller.clear();
    });
    final openAiApiKey = dotenv.env['OPENAI_API_KEY'];
    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
        'messages': [
          {'role': 'user', 'content': text}
        ]
      }),
    );

    if (res.statusCode == 200) {
      final reply = jsonDecode(res.body)['choices'][0]['message']['content'];
      setState(() => _messages.insert(0, {'role': 'AI Helper', 'text': reply}));
      await _tts.speak(reply);
    } else {
      setState(() => _messages.insert(0, {'role': 'AI Helper', 'text': 'Error'}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tech Case 2 - OpenAI')),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 20, right: 72, left: 16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (c, i) {
                  final m = _messages[i];
                  return ListTile(
                    title: Text(m['role']!),
                    subtitle: Text(m['text']!),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration:
                    const InputDecoration(hintText: 'Say or type...'),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _send(_controller.text)),
              ],
            ),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _listen,
        autofocus: false,
        isExtended: false,
        enableFeedback: true,
        child: Icon(_listening ? Icons.mic : Icons.mic_none),
      ),
    );
  }
}