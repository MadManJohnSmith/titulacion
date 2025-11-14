import 'dart:io';
import 'package:music_library/models/track.dart';
import 'package:music_library/models/user_settings.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = dirname(executablePath);
    String path = join(executableDir, 'music_library.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tracks(
        id TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        album TEXT,
        duration INTEGER,
        quality TEXT,
        source TEXT,
        filePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE albums(
        id TEXT PRIMARY KEY,
        title TEXT,
        artist TEXT,
        coverArtUrl TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE artists(
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists(
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_tracks(
        playlist_id TEXT,
        track_id TEXT,
        PRIMARY KEY (playlist_id, track_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id),
        FOREIGN KEY (track_id) REFERENCES tracks(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_settings(
        id INTEGER PRIMARY KEY,
        downloadQuality TEXT,
        libraryLocation TEXT,
        proxyAddress TEXT
      )
    ''');
  }

  Future<bool> trackExists(String id) async {
    final db = await database;
    final result = await db.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty;
  }

  Future<void> insertTrack(Track track) async {
    final db = await database;
    await db.insert(
      'tracks',
      {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'duration': track.duration,
        'quality': track.quality,
        'source': track.source,
        'filePath': track.filePath,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserSettings?> getUserSettings() async {
    final db = await database;
    final result = await db.query('user_settings');
    if (result.isNotEmpty) {
      final map = result.first;
      return UserSettings(
        downloadQuality: map['downloadQuality'] as String,
        libraryLocation: map['libraryLocation'] as String,
        proxyAddress: map['proxyAddress'] as String?,
      );
    }
    return null;
  }
}
