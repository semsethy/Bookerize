import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'library/library_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Needed because we open PdfDocuments directly (to render covers and count
  // pages) before any pdfrx widget has been built.
  pdfrxFlutterInitialize();

  // ProviderScope is where Riverpod keeps everything the app shares.
  runApp(const ProviderScope(child: BookerizeApp()));
}

class BookerizeApp extends StatelessWidget {
  const BookerizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookerize',
      debugShowCheckedModeBanner: false,
      theme: bookerizeTheme(),
      home: const LibraryScreen(),
    );
  }
}
