import 'package:flutter/material.dart';

class BartenderApp extends StatelessWidget {
  const BartenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bartender On Device',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(
        body: Center(child: Text('Bartender On Device')),
      ),
    );
  }
}
