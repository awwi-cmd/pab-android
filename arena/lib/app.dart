import 'package:flutter/material.dart';

/// Root widget. Routes and theme land here as screens are built (Phase 1).
class ArenaApp extends StatelessWidget {
  const ArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ARENA',
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Colors.black),
    );
  }
}
