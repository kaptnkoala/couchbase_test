import 'package:cbl/cbl.dart';
import 'package:cbl_flutter/cbl_flutter.dart';
import 'package:cbl_flutter_ee/cbl_flutter_ee.dart';
import 'package:path_provider/path_provider.dart';

class _Puzzle {
  final int id;
  final String solution;
  final List<String> copyrights;

  _Puzzle(this.id, this.solution, this.copyrights);
  _Puzzle.fromJson(Map<String, Object?> json)
      : id = json['id'] as int,
        solution = json['solution'] as String,
        copyrights = List<String>.from(json['copyrights'] as List);

  Map<String, Object> toJson() => {
        'id': id,
        'solution': solution,
        'copyrights': copyrights,
      };

  @override
  String toString() {
    return '_Puzzle{id: $id, solution: $solution, copyrights: $copyrights}';
  }
}

void testImport() async {
  final database = await initDatabase();
  final store = _Store('puzzle', database);

  var time = DateTime.now();
  final puzzles = List.generate(5000, (index) {
    return _Puzzle(1000 + index, 'WORD $index', List.generate(4, (index) => 'Copyright ${index + 1}'));
  });
  var duration = DateTime.now().difference(time);
  print('generate took ${duration.inMilliseconds / 1000}s');

  time = DateTime.now();
  await store.setMulti(Map.fromIterables(
    puzzles.map((puzzle) => '${puzzle.id}'),
    puzzles.map((puzzle) => puzzle.toJson()),
  ));
  duration = DateTime.now().difference(time);
  print('save took ${duration.inMilliseconds / 1000}s');

  time = DateTime.now();
  final puzzleKeys = await store.keys();
  duration = DateTime.now().difference(time);
  print('keys took ${duration.inMilliseconds / 1000}s');

  time = DateTime.now();
  final puzzleData = await store.getMulti(puzzleKeys);
  duration = DateTime.now().difference(time);
  print('get took ${duration.inMilliseconds / 1000}s');

  final loadedPuzzles = puzzleData.values.map((data) => _Puzzle.fromJson(data as Map<String, Object?>));
  print('loaded ${loadedPuzzles.length} puzzles, ${loadedPuzzles.first}');
}

Future<Database> initDatabase() async {
  CblFlutterEe.registerWith();
  await CouchbaseLiteFlutter.init();
  //Database.log.custom = DartConsoleLogger(LogLevel.verbose);

  final appDir = await getApplicationSupportDirectory();
  return await Database.openAsync(
    'test_import',
    DatabaseConfiguration(directory: appDir.path),
  );
}

class _Store {
  static const _separator = ':';
  static const _idKey = 'id';
  static const _typeKey = 'type';
  static const _valueKey = 'value';

  final String _type;
  final Database _database;

  _Store(this._type, this._database);

  Future<List<String>> keys() async {
    final query = QueryBuilder.createAsync()
        .select(SelectResult.expression(Meta.id))
        .from(DataSource.database(_database))
        .where(Expression.property(_typeKey).equalTo(Expression.string(_type)));

    final results = await query.execute();
    final list = results.asStream().map((result) => _parseId(result.string(0)!)).toList();
    final data = await list;
    return data;
  }

  Future<Map<String, Object>> getMulti(Iterable<String> keys) async {
    final keyMap = Map.fromIterables(keys.map(_createId), keys);
    final query = QueryBuilder.createAsync()
        .select(SelectResult.expression(Meta.id), SelectResult.expression(Expression.property(_valueKey)))
        .from(DataSource.database(_database))
        .where(Meta.id.in_(keyMap.keys.map(Expression.string)));

    final map = <String, Object>{};
    final results = await query.execute();
    await for (final result in results.asStream()) {
      final value = _unwrapValue(result.value(_valueKey));
      if (value != null) {
        final key = keyMap[result.string(_idKey)];
        map[key!] = value;
      }
    }

    return map;
  }

  Future<void> set(String key, Object? value) async {
    try {
      final docId = _createId(key);
      var document = (await _database.document(docId))?.toMutable();
      if (document == null) {
        document = MutableDocument.withId(docId);
        document.setString(_type, key: _typeKey);
      }

      document.setValue(value, key: _valueKey);
      await _database.saveDocument(document);
    } catch (error, trace) {
      rethrow;
    }
  }

  Future<void> setMulti(Map<String, Object> values) async {
    await _database.inBatch(() => Future.wait(values.entries.map((MapEntry entry) => set(entry.key, entry.value))));
  }

  String _parseId(String id) => id.replaceFirst('$_type$_separator', '');
  String _createId(String key) => '$_type$_separator$key';
  Object? _unwrapValue(Object? value) {
    if (value is Dictionary) {
      return value.toPlainMap();
    } else if (value is Array) {
      return value.toPlainList();
    }
    return value;
  }
}
