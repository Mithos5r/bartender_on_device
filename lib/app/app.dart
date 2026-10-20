import 'package:flutter/material.dart';

import '../core/model/model_service.dart';
import '../features/chat/ui/chat_screen.dart';
import '../features/chat/ui/setup_screen.dart';
import 'theme.dart';

class BartenderApp extends StatelessWidget {
  const BartenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bartender On Device',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _decideInitialScreen();
  }

  Future<void> _decideInitialScreen() async {
    try {
      final installed = await ModelService.instance.isModelInstalled();
      if (!mounted) return;
      setState(() {
        _initialScreen = installed ? const ChatScreen() : const SetupScreen();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialScreen = const SetupScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _initialScreen ??
        const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
