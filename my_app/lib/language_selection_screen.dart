import 'package:flutter/material.dart';
import 'mode_selection_screen.dart';
import 'api_services.dart'; // Ajout de l'API

class LanguageSelectionScreen extends StatefulWidget {
  @override
  _LanguageSelectionScreenState createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final ApiService _apiService = ApiService();
  
  final Map<String, String> languages = {
    'assets/UK.png': 'English',
    'assets/Spain.png': 'Español',
    'assets/France.png': 'Français',
    'assets/Italy.png': 'Italiano',
    'assets/Germany.png': 'Deutsch',
  };

  String selectedLanguage = 'English';
  String translatedText = "Select Mode";  // Texte à traduire

  final Map<String, String> languageCodes = {
    'English': 'en',
    'Español': 'es',
    'Français': 'fr',
    'Italiano': 'it',
    'Deutsch': 'de',
  };

  Future<void> translateText() async {
    try {
      String translation = await _apiService.translateText("Select Mode", languageCodes[selectedLanguage]!);
      setState(() {
        translatedText = translation;
      });
    } catch (e) {
      print("Erreur de traduction: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: Text("Epitech Flight Translator")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Select your language",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: screenWidth * 0.06, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: languages.keys.map((assetPath) {
              return GestureDetector(
                onTap: () async {
                  setState(() {
                    selectedLanguage = languages[assetPath]!;
                  });
                  await translateText();  // Appelle l'API pour traduire le texte
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ModeSelectionScreen(
                        selectedLanguage: selectedLanguage,
                        translatedText: translatedText,  // Texte traduit
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  assetPath,
                  width: screenWidth * 0.25,
                  height: screenWidth * 0.25,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
