import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:pdfrx/pdfrx.dart';

void main() {
  runApp(const BookerizeApp());
}

class BookerizeApp extends StatelessWidget {
  const BookerizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bookerize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4F3A)),
      ),
      home: const ReaderScreen(),
    );
  }
}

/// Finds the first PDF bundled under `assets/books/`.
///
/// The sample books are gitignored, so the filename differs from machine to
/// machine — hardcoding one would break on a fresh clone. `AssetManifest` is
/// the index Flutter builds at compile time of everything listed under
/// `flutter: assets:` in pubspec.yaml, so we can just ask it what shipped.
Future<String?> _findFirstBundledBook() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final books =
      manifest
          .listAssets()
          .where(
            (path) =>
                path.startsWith('assets/books/') &&
                path.toLowerCase().endsWith('.pdf'),
          )
          .toList()
        ..sort();
  return books.isEmpty ? null : books.first;
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // Kicked off once in initState rather than in build(), because build() can
  // run many times and would restart the lookup on every rebuild.
  late final Future<String?> _bookAsset = _findFirstBundledBook();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookerize')),
      // FutureBuilder rebuilds this subtree as the Future moves from
      // "still running" to "done", so we can show a spinner meanwhile.
      body: FutureBuilder<String?>(
        future: _bookAsset,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final asset = snapshot.data;
          if (asset == null) {
            return const _NoBookMessage();
          }
          // Text selection is on by default and Phases 4–5 depend on it,
          // so we deliberately pass no params that would disable it.
          return PdfViewer.asset(asset);
        },
      ),
    );
  }
}

class _NoBookMessage extends StatelessWidget {
  const _NoBookMessage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No book found.\n\n'
          'Sample books are gitignored. Copy a text-based PDF into '
          'assets/books/ and run the app again.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
