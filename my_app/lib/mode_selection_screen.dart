import 'package:flutter/material.dart';
import 'waiting_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  final String selectedLanguage;
  final String translatedText;

  ModeSelectionScreen({required this.selectedLanguage, required this.translatedText});

  final Map<String, Map<String, String>> modeTranslations = {
    'English': {
      'passenger': 'Passenger Mode',
      'crew_broadcast': 'Crew Broadcast Mode',
      'crew_conversation': 'Crew Conversation Mode'
    },
    'Español': {
      'passenger': 'Modo Pasajero',
      'crew_broadcast': 'Modo Difusión Tripulación',
      'crew_conversation': 'Modo Conversación Tripulación'
    },
    'Français': {
      'passenger': 'Mode Passager',
      'crew_broadcast': 'Mode Diffusion Équipage',
      'crew_conversation': 'Mode Conversation Équipage'
    },
    'Italiano': {
      'passenger': 'Modalità Passeggero',
      'crew_broadcast': 'Modalità Trasmissione Equipaggio',
      'crew_conversation': 'Modalità Conversazione Equipaggio'
    },
    'Deutsch': {
      'passenger': 'Passagiermodus',
      'crew_broadcast': 'Crew-Broadcast-Modus',
      'crew_conversation': 'Crew-Konversationsmodus'
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(translatedText)),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double buttonWidth = constraints.maxWidth * 0.7;
            double buttonHeight = constraints.maxHeight * 0.08;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var mode in modeTranslations[selectedLanguage]!.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: SizedBox(
                      width: buttonWidth,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WaitingScreen(
                                message: modeTranslations[selectedLanguage]![mode]!,
                                selectedLanguage: selectedLanguage,
                                mode: CrewMode.values[modeTranslations[selectedLanguage]!.keys.toList().indexOf(mode)],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          modeTranslations[selectedLanguage]![mode]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: constraints.maxWidth * 0.04),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
