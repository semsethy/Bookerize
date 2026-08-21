// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BooksTable extends Books with TableInfo<$BooksTable, Book> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _coverFileNameMeta = const VerificationMeta(
    'coverFileName',
  );
  @override
  late final GeneratedColumn<String> coverFileName = GeneratedColumn<String>(
    'cover_file_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPageMeta = const VerificationMeta(
    'lastPage',
  );
  @override
  late final GeneratedColumn<int> lastPage = GeneratedColumn<int>(
    'last_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _hasTextLayerMeta = const VerificationMeta(
    'hasTextLayer',
  );
  @override
  late final GeneratedColumn<bool> hasTextLayer = GeneratedColumn<bool>(
    'has_text_layer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_text_layer" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    fileName,
    coverFileName,
    pageCount,
    lastPage,
    hasTextLayer,
    addedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<Book> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('cover_file_name')) {
      context.handle(
        _coverFileNameMeta,
        coverFileName.isAcceptableOrUnknown(
          data['cover_file_name']!,
          _coverFileNameMeta,
        ),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('last_page')) {
      context.handle(
        _lastPageMeta,
        lastPage.isAcceptableOrUnknown(data['last_page']!, _lastPageMeta),
      );
    }
    if (data.containsKey('has_text_layer')) {
      context.handle(
        _hasTextLayerMeta,
        hasTextLayer.isAcceptableOrUnknown(
          data['has_text_layer']!,
          _hasTextLayerMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Book map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Book(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      coverFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_file_name'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      )!,
      lastPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_page'],
      )!,
      hasTextLayer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_text_layer'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class Book extends DataClass implements Insertable<Book> {
  final int id;
  final String title;

  /// File name inside `<documents>/books/`.
  final String fileName;

  /// File name inside `<documents>/covers/`. Null if the cover failed to render.
  final String? coverFileName;
  final int pageCount;

  /// 1-based, matching how pdfrx numbers pages.
  final int lastPage;

  /// False for scanned PDFs — no embedded text means no word lookup later.
  final bool hasTextLayer;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  const Book({
    required this.id,
    required this.title,
    required this.fileName,
    this.coverFileName,
    required this.pageCount,
    required this.lastPage,
    required this.hasTextLayer,
    required this.addedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || coverFileName != null) {
      map['cover_file_name'] = Variable<String>(coverFileName);
    }
    map['page_count'] = Variable<int>(pageCount);
    map['last_page'] = Variable<int>(lastPage);
    map['has_text_layer'] = Variable<bool>(hasTextLayer);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      title: Value(title),
      fileName: Value(fileName),
      coverFileName: coverFileName == null && nullToAbsent
          ? const Value.absent()
          : Value(coverFileName),
      pageCount: Value(pageCount),
      lastPage: Value(lastPage),
      hasTextLayer: Value(hasTextLayer),
      addedAt: Value(addedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory Book.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Book(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      fileName: serializer.fromJson<String>(json['fileName']),
      coverFileName: serializer.fromJson<String?>(json['coverFileName']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      lastPage: serializer.fromJson<int>(json['lastPage']),
      hasTextLayer: serializer.fromJson<bool>(json['hasTextLayer']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'fileName': serializer.toJson<String>(fileName),
      'coverFileName': serializer.toJson<String?>(coverFileName),
      'pageCount': serializer.toJson<int>(pageCount),
      'lastPage': serializer.toJson<int>(lastPage),
      'hasTextLayer': serializer.toJson<bool>(hasTextLayer),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  Book copyWith({
    int? id,
    String? title,
    String? fileName,
    Value<String?> coverFileName = const Value.absent(),
    int? pageCount,
    int? lastPage,
    bool? hasTextLayer,
    DateTime? addedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    fileName: fileName ?? this.fileName,
    coverFileName: coverFileName.present
        ? coverFileName.value
        : this.coverFileName,
    pageCount: pageCount ?? this.pageCount,
    lastPage: lastPage ?? this.lastPage,
    hasTextLayer: hasTextLayer ?? this.hasTextLayer,
    addedAt: addedAt ?? this.addedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  Book copyWithCompanion(BooksCompanion data) {
    return Book(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      coverFileName: data.coverFileName.present
          ? data.coverFileName.value
          : this.coverFileName,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      lastPage: data.lastPage.present ? data.lastPage.value : this.lastPage,
      hasTextLayer: data.hasTextLayer.present
          ? data.hasTextLayer.value
          : this.hasTextLayer,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Book(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('fileName: $fileName, ')
          ..write('coverFileName: $coverFileName, ')
          ..write('pageCount: $pageCount, ')
          ..write('lastPage: $lastPage, ')
          ..write('hasTextLayer: $hasTextLayer, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    fileName,
    coverFileName,
    pageCount,
    lastPage,
    hasTextLayer,
    addedAt,
    lastOpenedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Book &&
          other.id == this.id &&
          other.title == this.title &&
          other.fileName == this.fileName &&
          other.coverFileName == this.coverFileName &&
          other.pageCount == this.pageCount &&
          other.lastPage == this.lastPage &&
          other.hasTextLayer == this.hasTextLayer &&
          other.addedAt == this.addedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class BooksCompanion extends UpdateCompanion<Book> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> fileName;
  final Value<String?> coverFileName;
  final Value<int> pageCount;
  final Value<int> lastPage;
  final Value<bool> hasTextLayer;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastOpenedAt;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.fileName = const Value.absent(),
    this.coverFileName = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.hasTextLayer = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String fileName,
    this.coverFileName = const Value.absent(),
    required int pageCount,
    this.lastPage = const Value.absent(),
    this.hasTextLayer = const Value.absent(),
    required DateTime addedAt,
    this.lastOpenedAt = const Value.absent(),
  }) : title = Value(title),
       fileName = Value(fileName),
       pageCount = Value(pageCount),
       addedAt = Value(addedAt);
  static Insertable<Book> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? fileName,
    Expression<String>? coverFileName,
    Expression<int>? pageCount,
    Expression<int>? lastPage,
    Expression<bool>? hasTextLayer,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastOpenedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (fileName != null) 'file_name': fileName,
      if (coverFileName != null) 'cover_file_name': coverFileName,
      if (pageCount != null) 'page_count': pageCount,
      if (lastPage != null) 'last_page': lastPage,
      if (hasTextLayer != null) 'has_text_layer': hasTextLayer,
      if (addedAt != null) 'added_at': addedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? fileName,
    Value<String?>? coverFileName,
    Value<int>? pageCount,
    Value<int>? lastPage,
    Value<bool>? hasTextLayer,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastOpenedAt,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      coverFileName: coverFileName ?? this.coverFileName,
      pageCount: pageCount ?? this.pageCount,
      lastPage: lastPage ?? this.lastPage,
      hasTextLayer: hasTextLayer ?? this.hasTextLayer,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (coverFileName.present) {
      map['cover_file_name'] = Variable<String>(coverFileName.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (lastPage.present) {
      map['last_page'] = Variable<int>(lastPage.value);
    }
    if (hasTextLayer.present) {
      map['has_text_layer'] = Variable<bool>(hasTextLayer.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('fileName: $fileName, ')
          ..write('coverFileName: $coverFileName, ')
          ..write('pageCount: $pageCount, ')
          ..write('lastPage: $lastPage, ')
          ..write('hasTextLayer: $hasTextLayer, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BooksTable books = $BooksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [books];
}

typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  required String title,
  required String fileName,
  Value<String?> coverFileName,
  required int pageCount,
  Value<int> lastPage,
  Value<bool> hasTextLayer,
  required DateTime addedAt,
  Value<DateTime?> lastOpenedAt,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> fileName,
  Value<String?> coverFileName,
  Value<int> pageCount,
  Value<int> lastPage,
  Value<bool> hasTextLayer,
  Value<DateTime> addedAt,
  Value<DateTime?> lastOpenedAt,
});

class $$BooksTableFilterComposer extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverFileName => $composableBuilder(
    column: $table.coverFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasTextLayer => $composableBuilder(
    column: $table.hasTextLayer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverFileName => $composableBuilder(
    column: $table.coverFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasTextLayer => $composableBuilder(
    column: $table.hasTextLayer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get coverFileName => $composableBuilder(
    column: $table.coverFileName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get lastPage =>
      $composableBuilder(column: $table.lastPage, builder: (column) => column);

  GeneratedColumn<bool> get hasTextLayer => $composableBuilder(
    column: $table.hasTextLayer,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BooksTable,
          Book,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
          Book,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$AppDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String?> coverFileName = const Value.absent(),
                Value<int> pageCount = const Value.absent(),
                Value<int> lastPage = const Value.absent(),
                Value<bool> hasTextLayer = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                title: title,
                fileName: fileName,
                coverFileName: coverFileName,
                pageCount: pageCount,
                lastPage: lastPage,
                hasTextLayer: hasTextLayer,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String fileName,
                Value<String?> coverFileName = const Value.absent(),
                required int pageCount,
                Value<int> lastPage = const Value.absent(),
                Value<bool> hasTextLayer = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
              }) => BooksCompanion.insert(
                id: id,
                title: title,
                fileName: fileName,
                coverFileName: coverFileName,
                pageCount: pageCount,
                lastPage: lastPage,
                hasTextLayer: hasTextLayer,
                addedAt: addedAt,
                lastOpenedAt: lastOpenedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BooksTable,
      Book,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (Book, BaseReferences<_$AppDatabase, $BooksTable, Book>),
      Book,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
}
