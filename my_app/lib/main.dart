import 'package:flutter/material.dart';
import 'language_selection_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Epitech Flight Translator',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LanguageSelectionScreen(),
    );
  }
}