import 'package:flutter/material.dart';
import 'dart:async';
import 'api_services.dart';

enum CrewMode { passenger, broadcast, crew_conversation }

class WaitingScreen extends StatefulWidget {
  final String message;
  final String selectedLanguage;
  final CrewMode mode;

  WaitingScreen({
    required this.message,
    required this.selectedLanguage,
    required this.mode,
  });

  @override
  _WaitingScreenState createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  Timer? _timer;
  String? passengerLanguage;

  final Map<String, String> languageFlags = {
    'Français': 'assets/France.png',
    'English': 'assets/UK.png',
    'Español': 'assets/Spain.png',
    'Deutsch': 'assets/Germany.png',
    'Italiano': 'assets/Italy.png',
  };

  @override
  void initState() {
    super.initState();
    passengerLanguage = widget.selectedLanguage; // Définit une langue par défaut

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode == CrewMode.crew_conversation) {
        _selectPassengerLanguage();
      } else {
        _fetchMessages();
        
        _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchMessages());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectPassengerLanguage() async {
    await Future.delayed(Duration(milliseconds: 500));
    String? selectedLang = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Sélectionnez la langue du passager"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: languageFlags.entries.map((entry) {
                return ListTile(
                  leading: Image.asset(entry.value, width: 30, height: 20),
                  title: Text(entry.key),
                  onTap: () {
                    Navigator.of(context).pop(entry.key);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (selectedLang != null) {
      setState(() {
        passengerLanguage = selectedLang;
      });
      _fetchMessages();
      _timer = Timer.periodic(Duration(seconds: 5), (_) => _fetchMessages());
    }
  }

  Future<void> _fetchMessages() async {
    try {
      String modeKey = widget.mode == CrewMode.crew_conversation ? "crew_conversation" : widget.mode.toString().split('.').last;
      List<dynamic> response = await _apiService.getMessages(modeKey);

      setState(() {
        messages = response.map((message) => {
          'text': message['text'],
          'translated': message['translated']
        }).toList();
      });
    } catch (e) {
      print('❌ Erreur de récupération des messages: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      print("⚠️ Aucun message à envoyer.");
      return;
    }

    try {
      if (passengerLanguage == null) {
        print("❌ Erreur : `passengerLanguage` est null.");
        return;
      }

      String sourceLang = widget.selectedLanguage;
      String targetLang = passengerLanguage!;

      print("🔄 Envoi du message de $sourceLang vers $targetLang");

      String translatedText = await _apiService.translateText(
        _messageController.text,
        targetLang,
      );

      String modeKey = widget.mode == CrewMode.crew_conversation ? "crew_conversation" : widget.mode.toString().split('.').last;

      await _apiService.sendMessage(
        translatedText,
        sourceLang,
        targetLang,
        modeKey,
      );

      _messageController.clear();
      _fetchMessages();
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
    }
  }

@override
Widget build(BuildContext context) {
  bool canSendMessages = widget.mode != CrewMode.passenger;

  return Scaffold(
    appBar: AppBar(title: Text(widget.message)),
    body: Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(child: Text("Aucun message reçu"))
              : ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    // Afficher uniquement le message traduit
                    return ListTile(
                      title: Text(message['translated'] ?? "Erreur de traduction"),
                    );
                  },
                ),
        ),
        if (canSendMessages)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: 'Tapez un message...'),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
      ],
    ),
  );
}
}