import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/inventory_item.dart';
import '../models/preset.dart';
import '../models/product.dart';
import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../models/shopping_session.dart';
import 'image_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'shopping_storage.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        barcode    TEXT PRIMARY KEY,
        name       TEXT NOT NULL,
        brand      TEXT,
        store      TEXT,
        photo_path TEXT,
        price      REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE price_history (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode     TEXT NOT NULL,
        price       REAL NOT NULL,
        recorded_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        barcode  TEXT PRIMARY KEY,
        quantity REAL NOT NULL DEFAULT 0,
        unit     TEXT NOT NULL DEFAULT 'units',
        FOREIGN KEY (barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_sessions (
        id     INTEGER PRIMARY KEY AUTOINCREMENT,
        place  TEXT,
        date   TEXT NOT NULL DEFAULT (datetime('now')),
        status TEXT NOT NULL DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE shopping_items (
        session_id INTEGER NOT NULL,
        barcode    TEXT NOT NULL,
        price      REAL NOT NULL DEFAULT 0,
        quantity   REAL NOT NULL DEFAULT 1,
        checked    INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (session_id, barcode),
        FOREIGN KEY (session_id) REFERENCES shopping_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (barcode)    REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE presets (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE preset_items (
        preset_id INTEGER NOT NULL,
        barcode   TEXT NOT NULL,
        quantity  REAL NOT NULL DEFAULT 1,
        unit      TEXT NOT NULL DEFAULT 'units',
        PRIMARY KEY (preset_id, barcode),
        FOREIGN KEY (preset_id) REFERENCES presets(id) ON DELETE CASCADE,
        FOREIGN KEY (barcode)   REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipes (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_ingredients (
        recipe_id INTEGER NOT NULL,
        barcode   TEXT NOT NULL,
        quantity  REAL NOT NULL DEFAULT 1,
        unit      TEXT NOT NULL DEFAULT 'units',
        PRIMARY KEY (recipe_id, barcode),
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE,
        FOREIGN KEY (barcode)   REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_steps (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id      INTEGER NOT NULL,
        step_order     INTEGER NOT NULL,
        description    TEXT NOT NULL,
        wait_time_secs INTEGER,
        result_note    TEXT,
        FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE step_photos (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        step_id    INTEGER NOT NULL,
        photo_path TEXT NOT NULL,
        FOREIGN KEY (step_id) REFERENCES recipe_steps(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Start fresh — drop all old tables then recreate
    for (final t in [
      'shopping_items', 'item_prices', 'shopping_sessions', 'items',
      'step_photos', 'recipe_steps', 'recipe_ingredients', 'recipes',
      'preset_items', 'presets', 'inventory', 'price_history', 'products',
    ]) {
      await db.execute('DROP TABLE IF EXISTS $t');
    }
    await _onCreate(db, newVersion);
  }

  // ─── Products ────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<void> insertProduct(Product p) async {
    final db = await database;
    await db.insert('products', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('inventory', {'barcode': p.barcode, 'quantity': 0, 'unit': 'units'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await recordPrice(p.barcode, p.price);
  }

  Future<void> updateProduct(Product p) async {
    final db = await database;
    await db.update('products', p.toMap(), where: 'barcode = ?', whereArgs: [p.barcode]);
    await recordPrice(p.barcode, p.price);
  }

  Future<void> deleteProduct(String barcode) async {
    final db = await database;
    final rows = await db.query('products', columns: ['photo_path'],
        where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isNotEmpty) {
      await ImageHelper.deleteImage(rows.first['photo_path'] as String?);
    }
    await db.delete('products', where: 'barcode = ?', whereArgs: [barcode]);
  }

  // ─── Inventory ───────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventory() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.barcode, p.name, p.brand, p.photo_path,
             COALESCE(i.quantity, 0) AS quantity,
             COALESCE(i.unit, 'units') AS unit
      FROM products p
      LEFT JOIN inventory i ON p.barcode = i.barcode
      ORDER BY p.name ASC
    ''');
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<Map<String, double>> getInventoryMap() async {
    final db = await database;
    final rows = await db.query('inventory');
    return {for (final r in rows) r['barcode'] as String: (r['quantity'] as num).toDouble()};
  }

  Future<void> setInventoryQuantity(String barcode, double qty, String unit) async {
    final db = await database;
    await db.insert('inventory', {'barcode': barcode, 'quantity': qty, 'unit': unit},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _addToInventory(Database db, String barcode, double delta) async {
    final rows = await db.query('inventory', where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) {
      await db.insert('inventory', {'barcode': barcode, 'quantity': delta, 'unit': 'units'});
    } else {
      final current = (rows.first['quantity'] as num).toDouble();
      await db.update('inventory', {'quantity': current + delta},
          where: 'barcode = ?', whereArgs: [barcode]);
    }
  }

  // ─── Shopping Sessions ───────────────────────────────────────────────────

  Future<int> getOrCreateActiveSession() async {
    final db = await database;
    final rows = await db.query('shopping_sessions',
        where: 'status = ?', whereArgs: ['active'], orderBy: 'id DESC', limit: 1);
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return await db.insert('shopping_sessions', {'status': 'active'});
  }

  Future<void> completeSession(int sessionId) async {
    final db = await database;
    final checkedItems = await db.rawQuery('''
      SELECT barcode, price, quantity FROM shopping_items
      WHERE session_id = ? AND checked = 1
    ''', [sessionId]);

    for (final item in checkedItems) {
      final barcode = item['barcode'] as String;
      final price = (item['price'] as num).toDouble();
      final qty = (item['quantity'] as num).toDouble();
      await recordPrice(barcode, price);
      await _addToInventory(db, barcode, qty);
    }

    await db.update('shopping_sessions', {'status': 'completed'},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<List<ShoppingSession>> getCompletedSessions() async {
    final db = await database;
    final rows = await db.query('shopping_sessions',
        where: 'status = ?', whereArgs: ['completed'], orderBy: 'date DESC');
    return rows.map(ShoppingSession.fromMap).toList();
  }

  Future<void> deleteShoppingSession(int sessionId) async {
    final db = await database;
    await db.delete('shopping_sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  // ─── Shopping Items ──────────────────────────────────────────────────────

  Future<List<ShoppingItem>> getShoppingListItems(int sessionId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT si.session_id, si.barcode, si.price, si.quantity, si.checked,
             p.name, p.brand
      FROM shopping_items si
      JOIN products p ON si.barcode = p.barcode
      WHERE si.session_id = ?
      ORDER BY si.checked ASC, p.name ASC
    ''', [sessionId]);
    return rows.map(ShoppingItem.fromMap).toList();
  }

  Future<void> addItemToList(
      int sessionId, String barcode, double qty, double price) async {
    final db = await database;
    await db.insert(
      'shopping_items',
      {'session_id': sessionId, 'barcode': barcode, 'quantity': qty, 'price': price, 'checked': 0},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeItemFromList(int sessionId, String barcode) async {
    final db = await database;
    await db.delete('shopping_items',
        where: 'session_id = ? AND barcode = ?', whereArgs: [sessionId, barcode]);
  }

  Future<void> updateItemInList(int sessionId, String barcode,
      {double? qty, double? price}) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (qty != null) updates['quantity'] = qty;
    if (price != null) updates['price'] = price;
    if (updates.isEmpty) return;
    await db.update('shopping_items', updates,
        where: 'session_id = ? AND barcode = ?', whereArgs: [sessionId, barcode]);
  }

  Future<void> setItemChecked(int sessionId, String barcode, bool checked) async {
    final db = await database;
    await db.update('shopping_items', {'checked': checked ? 1 : 0},
        where: 'session_id = ? AND barcode = ?', whereArgs: [sessionId, barcode]);
  }

  // ─── Presets ─────────────────────────────────────────────────────────────

  Future<List<Preset>> getPresets() async {
    final db = await database;
    final rows = await db.query('presets', orderBy: 'name ASC');
    return rows.map(Preset.fromMap).toList();
  }

  Future<void> createPreset(String name, List<PresetItem> items) async {
    final db = await database;
    final id = await db.insert('presets', {'name': name});
    for (final item in items) {
      await db.insert('preset_items', {
        'preset_id': id,
        'barcode': item.barcode,
        'quantity': item.quantity,
        'unit': item.unit,
      });
    }
  }

  Future<void> deletePreset(int presetId) async {
    final db = await database;
    await db.delete('presets', where: 'id = ?', whereArgs: [presetId]);
  }

  Future<void> loadPresetIntoSession(int presetId, int sessionId) async {
    final db = await database;
    final presetRows = await db.rawQuery('''
      SELECT pi.barcode, pi.quantity, pi.unit, p.price
      FROM preset_items pi
      JOIN products p ON pi.barcode = p.barcode
      WHERE pi.preset_id = ?
    ''', [presetId]);

    final existing = await db.query('shopping_items',
        columns: ['barcode'], where: 'session_id = ?', whereArgs: [sessionId]);
    final existingBarcodes = existing.map((r) => r['barcode'] as String).toSet();

    for (final row in presetRows) {
      final barcode = row['barcode'] as String;
      if (!existingBarcodes.contains(barcode)) {
        await db.insert('shopping_items', {
          'session_id': sessionId,
          'barcode': barcode,
          'quantity': row['quantity'],
          'price': row['price'],
          'checked': 0,
        });
      }
    }
  }

  Future<List<PresetItem>> getPresetItems(int presetId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT pi.preset_id, pi.barcode, pi.quantity, pi.unit, p.name
      FROM preset_items pi
      JOIN products p ON pi.barcode = p.barcode
      WHERE pi.preset_id = ?
    ''', [presetId]);
    return rows.map(PresetItem.fromMap).toList();
  }

  // ─── Recipes ─────────────────────────────────────────────────────────────

  Future<Map<int, bool?>> getRecipesFeasibility() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT r.id,
        CASE
          WHEN COUNT(ri.barcode) = 0 THEN NULL
          WHEN SUM(CASE WHEN COALESCE(inv.quantity, 0) < ri.quantity THEN 1 ELSE 0 END) = 0 THEN 1
          ELSE 0
        END AS feasible
      FROM recipes r
      LEFT JOIN recipe_ingredients ri ON r.id = ri.recipe_id
      LEFT JOIN inventory inv ON ri.barcode = inv.barcode
      GROUP BY r.id
    ''');
    return {
      for (final row in rows)
        row['id'] as int: row['feasible'] == null ? null : row['feasible'] == 1,
    };
  }

  Future<List<Recipe>> getRecipes() async {
    final db = await database;
    final rows = await db.query('recipes', orderBy: 'name ASC');
    return rows.map(Recipe.fromMap).toList();
  }

  Future<Recipe?> getRecipeById(int id) async {
    final db = await database;
    final rows = await db.query('recipes', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Recipe.fromMap(rows.first);
  }

  Future<int> insertRecipe(Recipe recipe) async {
    final db = await database;
    return await db.insert('recipes', recipe.toMap());
  }

  Future<void> updateRecipe(Recipe recipe) async {
    final db = await database;
    await db.update('recipes', recipe.toMap(), where: 'id = ?', whereArgs: [recipe.id]);
  }

  Future<void> deleteRecipe(int id) async {
    final db = await database;
    // collect and delete step photos from filesystem
    final steps = await db.query('recipe_steps', columns: ['id'], where: 'recipe_id = ?', whereArgs: [id]);
    for (final step in steps) {
      final photos = await db.query('step_photos',
          columns: ['photo_path'], where: 'step_id = ?', whereArgs: [step['id']]);
      for (final photo in photos) {
        await ImageHelper.deleteImage(photo['photo_path'] as String?);
      }
    }
    await db.delete('recipes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecipeIngredient>> getRecipeIngredients(int recipeId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT ri.recipe_id, ri.barcode, ri.quantity, ri.unit,
             p.name, p.brand
      FROM recipe_ingredients ri
      JOIN products p ON ri.barcode = p.barcode
      WHERE ri.recipe_id = ?
    ''', [recipeId]);
    return rows.map(RecipeIngredient.fromMap).toList();
  }

  Future<void> upsertRecipeIngredient(RecipeIngredient ingredient) async {
    final db = await database;
    await db.insert('recipe_ingredients', ingredient.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecipeIngredient(int recipeId, String barcode) async {
    final db = await database;
    await db.delete('recipe_ingredients',
        where: 'recipe_id = ? AND barcode = ?', whereArgs: [recipeId, barcode]);
  }

  Future<List<RecipeStep>> getRecipeSteps(int recipeId) async {
    final db = await database;
    final rows = await db.query('recipe_steps',
        where: 'recipe_id = ?', whereArgs: [recipeId], orderBy: 'step_order ASC');
    return rows.map(RecipeStep.fromMap).toList();
  }

  Future<int> insertRecipeStep(RecipeStep step) async {
    final db = await database;
    return await db.insert('recipe_steps', step.toMap());
  }

  Future<void> updateRecipeStep(RecipeStep step) async {
    final db = await database;
    await db.update('recipe_steps', step.toMap(), where: 'id = ?', whereArgs: [step.id]);
  }

  Future<void> deleteRecipeStep(int stepId) async {
    final db = await database;
    final photos = await db.query('step_photos',
        columns: ['photo_path'], where: 'step_id = ?', whereArgs: [stepId]);
    for (final photo in photos) {
      await ImageHelper.deleteImage(photo['photo_path'] as String?);
    }
    await db.delete('recipe_steps', where: 'id = ?', whereArgs: [stepId]);
  }

  Future<List<StepPhoto>> getStepPhotos(int stepId) async {
    final db = await database;
    final rows = await db.query('step_photos', where: 'step_id = ?', whereArgs: [stepId]);
    return rows.map(StepPhoto.fromMap).toList();
  }

  Future<void> insertStepPhoto(StepPhoto photo) async {
    final db = await database;
    await db.insert('step_photos', photo.toMap());
  }

  Future<void> deleteStepPhoto(int photoId, String path) async {
    final db = await database;
    await ImageHelper.deleteImage(path);
    await db.delete('step_photos', where: 'id = ?', whereArgs: [photoId]);
  }

  Future<String?> getLastRecipePhoto(int recipeId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT sp.photo_path
      FROM step_photos sp
      JOIN recipe_steps rs ON sp.step_id = rs.id
      WHERE rs.recipe_id = ?
      ORDER BY rs.step_order DESC, sp.id DESC
      LIMIT 1
    ''', [recipeId]);
    if (rows.isEmpty) return null;
    return rows.first['photo_path'] as String?;
  }

  Future<List<RecipeIngredient>> getMissingIngredients(int recipeId) async {
    final ingredients = await getRecipeIngredients(recipeId);
    final invMap = await getInventoryMap();
    return ingredients.where((ing) {
      final inStock = invMap[ing.barcode] ?? 0.0;
      return inStock < ing.quantity;
    }).toList();
  }

  // ─── Statistics ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProductSessionHistory(String barcode) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ss.id, ss.date, si.quantity, si.price
      FROM shopping_items si
      JOIN shopping_sessions ss ON si.session_id = ss.id
      WHERE si.barcode = ? AND ss.status = 'completed'
      ORDER BY ss.date ASC
    ''', [barcode]);
  }

  Future<List<Map<String, dynamic>>> getProductPriceHistory(String barcode) async {
    final db = await database;
    return await db.query('price_history',
        where: 'barcode = ?', whereArgs: [barcode], orderBy: 'recorded_at ASC');
  }

  // ─── Price tracking ──────────────────────────────────────────────────────

  Future<void> recordPrice(String barcode, double price) async {
    if (price <= 0) return;
    final db = await database;
    final last = await db.query('price_history',
        where: 'barcode = ?', whereArgs: [barcode], orderBy: 'recorded_at DESC', limit: 1);
    if (last.isNotEmpty && (last.first['price'] as num).toDouble() == price) return;
    await db.insert('price_history', {'barcode': barcode, 'price': price});
  }

  Future<double> getLatestPrice(String barcode) async {
    final db = await database;
    final rows = await db.query('price_history',
        where: 'barcode = ?', whereArgs: [barcode], orderBy: 'recorded_at DESC', limit: 1);
    if (rows.isNotEmpty) return (rows.first['price'] as num).toDouble();
    final product = await db.query('products',
        columns: ['price'], where: 'barcode = ?', whereArgs: [barcode]);
    if (product.isNotEmpty) return (product.first['price'] as num).toDouble();
    return 0.0;
  }
}
