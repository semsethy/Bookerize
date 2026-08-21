import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app_database.dart';

/// What happened when a PDF was brought into the library.
enum ImportResult { added, alreadyPresent, failed }

class ImportOutcome {
  const ImportOutcome(this.result, {this.title, this.hasTextLayer = true});

  final ImportResult result;
  final String? title;

  /// False for scanned PDFs. They still import — they just can't be looked up
  /// word by word later, and the caller says so.
  final bool hasTextLayer;
}

/// Owns everything on disk: the PDF copies, the rendered covers, and the rows
/// in the database that point at them.
class BookRepository {
  BookRepository(this._db);

  final AppDatabase _db;

  Directory? _books;
  Directory? _covers;

  /// Must be awaited once before any path helper is used. Safe to call again.
  Future<void> init() async {
    if (_books != null) return;
    final docs = await getApplicationDocumentsDirectory();
    _books = await Directory(p.join(docs.path, 'books'))
        .create(recursive: true);
    _covers = await Directory(p.join(docs.path, 'covers'))
        .create(recursive: true);
  }

  Directory get _booksDir => _requireReady(_books);
  Directory get _coversDir => _requireReady(_covers);

  /// A `late final` field fails here with an unreadable
  /// "LateInitializationError: Field '_booksDir@45075665'". This says what to do.
  Directory _requireReady(Directory? dir) {
    if (dir == null) {
      throw StateError(
        'BookRepository.init() must finish before file paths are used. '
        'Watch startupProvider before reading a book path.',
      );
    }
    return dir;
  }

  String pdfPathOf(Book book) => p.join(_booksDir.path, book.fileName);

  String? coverPathOf(Book book) {
    final name = book.coverFileName;
    return name == null ? null : p.join(_coversDir.path, name);
  }

  /// Copies any PDFs bundled under `assets/books/` into storage on first run,
  /// so a fresh install has something to open instead of an empty shelf.
  Future<void> seedBundledBooks() async {
    await init();
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled =
        manifest
            .listAssets()
            .where(
              (a) =>
                  a.startsWith('assets/books/') &&
                  a.toLowerCase().endsWith('.pdf'),
            )
            .toList()
          ..sort();

    for (final asset in bundled) {
      final fileName = p.basename(asset);
      if (await _db.findByFileName(fileName) != null) continue;

      final destination = File(p.join(_booksDir.path, fileName));
      if (!await destination.exists()) {
        final bytes = await rootBundle.load(asset);
        await destination.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      }
      await _register(destination, fileName);
    }
  }

  /// Copies a picked PDF into app storage and records it.
  Future<ImportOutcome> importFrom(String sourcePath) async {
    await init();
    try {
      final fileName = await _uniqueFileName(p.basename(sourcePath));
      final existing = await _db.findByFileName(p.basename(sourcePath));
      if (existing != null) {
        return ImportOutcome(
          ImportResult.alreadyPresent,
          title: existing.title,
        );
      }

      final destination = File(p.join(_booksDir.path, fileName));
      await File(sourcePath).copy(destination.path);
      return await _register(destination, fileName);
    } on Object {
      return const ImportOutcome(ImportResult.failed);
    }
  }

  Future<void> remove(Book book) async {
    await init();
    final pdf = File(pdfPathOf(book));
    if (await pdf.exists()) await pdf.delete();
    final cover = coverPathOf(book);
    if (cover != null && await File(cover).exists()) await File(cover).delete();
    await _db.deleteBook(book.id);
  }

  /// Opens the PDF once to collect everything we need: page count, whether it
  /// has a text layer, and a cover rendered from page one.
  Future<ImportOutcome> _register(File pdf, String fileName) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(pdf.path);
      final pageCount = doc.pages.length;
      final hasText = await _hasTextLayer(doc);
      final coverName = await _renderCover(doc, fileName);
      final title = titleFromFileName(fileName);

      await _db.insertBook(
        BooksCompanion.insert(
          title: title,
          fileName: fileName,
          pageCount: pageCount,
          coverFileName: Value(coverName),
          hasTextLayer: Value(hasText),
          addedAt: DateTime.now(),
        ),
      );
      return ImportOutcome(
        ImportResult.added,
        title: title,
        hasTextLayer: hasText,
      );
    } on Object {
      if (await pdf.exists()) await pdf.delete();
      return const ImportOutcome(ImportResult.failed);
    } finally {
      await doc?.dispose();
    }
  }

  /// Samples pages across the book rather than trusting page one — front matter
  /// is often a full-page image even in books that are text all the way through.
  Future<bool> _hasTextLayer(PdfDocument doc) async {
    final total = doc.pages.length;
    if (total == 0) return false;
    final step = (total / 12).ceil().clamp(1, total);
    for (var i = 0; i < total; i += step) {
      final text = await doc.pages[i].loadText();
      if ((text?.fullText.trim().length ?? 0) > 20) return true;
    }
    return false;
  }

  /// The cover is page one, rendered by the PDF engine — no artwork needed.
  Future<String?> _renderCover(PdfDocument doc, String fileName) async {
    if (doc.pages.isEmpty) return null;
    PdfImage? rendered;
    ui.Image? image;
    try {
      final page = doc.pages.first;
      const targetWidth = 600.0;
      final scale = targetWidth / page.width;
      rendered = await page.render(
        fullWidth: targetWidth,
        fullHeight: page.height * scale,
        backgroundColor: 0xFFFFFFFF,
      );
      if (rendered == null) return null;

      image = await rendered.createImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;

      final coverName = '${p.basenameWithoutExtension(fileName)}.png';
      await File(p.join(_coversDir.path, coverName))
          .writeAsBytes(png.buffer.asUint8List(), flush: true);
      return coverName;
    } on Object {
      // A missing cover is a cosmetic problem, not a reason to refuse the book.
      return null;
    } finally {
      rendered?.dispose();
      image?.dispose();
    }
  }

  Future<String> _uniqueFileName(String wanted) async {
    var candidate = wanted;
    var n = 2;
    while (await File(p.join(_booksDir.path, candidate)).exists()) {
      candidate =
          '${p.basenameWithoutExtension(wanted)} ($n)${p.extension(wanted)}';
      n++;
    }
    return candidate;
  }

  /// `the_communication_book_44_ideas.pdf` → `The Communication Book 44 Ideas`.
  static String titleFromFileName(String fileName) {
    // Not basenameWithoutExtension: `path` treats a name like ".pdf" as a
    // hidden file with no extension, and would hand back ".pdf" as the title.
    final base = p
        .basename(fileName)
        .replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');

    final words = base
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1));
    final title = words.join(' ');
    return title.isEmpty ? 'Untitled' : title;
  }
}
