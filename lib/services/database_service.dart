import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/scan_model.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  
  // In-memory storage for Web
  static final List<ScanModel> _webScans = [];
  static final Map<String, String> _webSettings = {};

  DatabaseService._init();

  Future<Database?> get database async {
    // Skip database initialization on Web
    if (kIsWeb) return null;
    
    if (_database != null) return _database!;
    _database = await _initDB('lidar_scanner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        // Enable foreign keys
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE scans (
        id $idType,
        name $textType,
        createdAt $textType,
        quality $realType,
        filePath $textTypeNullable,
        isUploaded $intType,
        metadata $textTypeNullable
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key $textType PRIMARY KEY,
        value $textTypeNullable
      )
    ''');
  }

  // Scan operations
  Future<void> createScan(ScanModel scan) async {
    if (kIsWeb) {
      // Web: Use in-memory storage
      _webScans.add(scan);
      return;
    }
    
    final db = await instance.database;
    await db!.insert('scans', scan.toJson());
  }

  Future<List<ScanModel>> getAllScans() async {
    if (kIsWeb) {
      // Web: Return in-memory scans
      _webScans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _webScans;
    }
    
    final db = await instance.database;
    final result = await db!.query('scans', orderBy: 'createdAt DESC');
    return result.map((json) => ScanModel.fromJson(json)).toList();
  }

  Future<ScanModel?> getScan(String id) async {
    if (kIsWeb) {
      // Web: Find in memory
      try {
        return _webScans.firstWhere((scan) => scan.id == id);
      } catch (e) {
        return null;
      }
    }
    
    final db = await instance.database;
    final maps = await db!.query(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ScanModel.fromJson(maps.first);
    }
    return null;
  }

  Future<int> updateScan(ScanModel scan) async {
    if (kIsWeb) {
      // Web: Update in memory
      final index = _webScans.indexWhere((s) => s.id == scan.id);
      if (index != -1) {
        _webScans[index] = scan;
        return 1;
      }
      return 0;
    }
    
    final db = await instance.database;
    return db!.update(
      'scans',
      scan.toJson(),
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  Future<int> deleteScan(String id) async {
    if (kIsWeb) {
      // Web: Delete from memory
      final initialLength = _webScans.length;
      _webScans.removeWhere((scan) => scan.id == id);
      return initialLength - _webScans.length;
    }
    
    final db = await instance.database;
    return await db!.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Settings operations
  Future<void> saveSetting(String key, String value) async {
    if (kIsWeb) {
      // Web: Use in-memory storage
      _webSettings[key] = value;
      return;
    }
    
    final db = await instance.database;
    await db!.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    if (kIsWeb) {
      // Web: Get from memory
      return _webSettings[key];
    }
    
    final db = await instance.database;
    final result = await db!.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future close() async {
    if (kIsWeb) return;
    
    final db = await instance.database;
    db?.close();
  }
}
