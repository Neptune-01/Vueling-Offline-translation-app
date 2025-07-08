import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = "http://10.0.2.2:8000/api/v1";

  final Map<String, String> languageCodes = {
    "Français": "fr",
    "English": "en",
    "Español": "es",
    "Deutsch": "de",
    "Italiano": "it",
  };

  Future<String> translateText(String text, String targetLang) async {
    try {
      // 🔹 Convertir en code langue correct (ex: Français → fr)
      targetLang = languageCodes[targetLang] ?? targetLang;

      print("🟡 Envoi de la requête de traduction : $text vers $targetLang");

      final response = await http.post(
        Uri.parse('$baseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'target_language': targetLang,
          'source_language': "auto",
        }),
      );

      print("🟡 Réponse reçue: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['translation'];
      } else {
        throw Exception('Échec de la traduction: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de la traduction: $e');
      return text;
    }
  }

  // 🔹 ✅ Ajout de getMessages
  Future<List<dynamic>> getMessages(String mode) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/messages/$mode'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Échec de récupération des messages: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de la récupération des messages: $e');
      return [];
    }
  }

  Future<void> sendMessage(String text, String sourceLang, String targetLang, String mode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'source_language': sourceLang,
          'target_language': targetLang,
          'mode': mode
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Échec d\'envoi du message: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erreur lors de l\'envoi du message: $e');
    }
  }
}
