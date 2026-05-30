import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utilities/database_helper.dart';
import 'recipe_cook_page.dart';
import 'recipe_detail_page.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> with AutomaticKeepAliveClientMixin {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();

  List<Recipe> _all = [];
  List<Recipe> _filtered = [];
  final Map<int, String?> _lastPhotos = {};
  final Map<int, bool?> _feasibility = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    final recipes = await _db.getRecipes();
    final feasibility = await _db.getRecipesFeasibility();
    final photos = <int, String?>{};
    for (final r in recipes) {
      if (r.id != null) photos[r.id!] = await _db.getLastRecipePhoto(r.id!);
    }
    if (!mounted) return;
    setState(() {
      _all = recipes;
      _lastPhotos
        ..clear()
        ..addAll(photos);
      _feasibility
        ..clear()
        ..addAll(feasibility);
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.of(_all)
          : _all.where((r) => r.name.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _openCookMode(Recipe r) async {
    final ingredients = await _db.getRecipeIngredients(r.id!);
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeCookPage(
          recipeId: r.id!,
          recipeName: r.name,
          ingredients: ingredients,
        ),
      ),
    );
    if (changed == true) _loadRecipes();
  }

  Future<void> _openEdit({int? recipeId}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RecipeDetailPage(recipeId: recipeId)),
    );
    if (changed == true) _loadRecipes();
  }

  Future<bool> _confirmDelete(Recipe recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Remove "${recipe.name}"? Steps and photos will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _feasibilityIcon(int? recipeId) {
    if (recipeId == null) return const SizedBox.shrink();
    final f = _feasibility[recipeId];
    if (f == null) {
      return const Tooltip(
        message: 'No ingredients defined',
        child: Icon(Icons.help_outline, color: Colors.grey, size: 20),
      );
    }
    if (f) {
      return const Tooltip(
        message: 'Ready to cook',
        child: Icon(Icons.check_circle, color: Colors.green, size: 20),
      );
    }
    return const Tooltip(
      message: 'Missing ingredients',
      child: Icon(Icons.cancel, color: Colors.red, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilter();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_rounded,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              _all.isEmpty
                                  ? 'No recipes yet.\nTap + to create one.'
                                  : 'No results.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRecipes,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final r = _filtered[i];
                            final photo = r.id != null ? _lastPhotos[r.id] : null;
                            return Dismissible(
                              key: ValueKey(r.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDelete(r),
                              onDismissed: (_) async {
                                await _db.deleteRecipe(r.id!);
                                setState(() {
                                  _all.removeWhere((x) => x.id == r.id);
                                  _filtered.removeAt(i);
                                  if (r.id != null) {
                                    _lastPhotos.remove(r.id);
                                    _feasibility.remove(r.id);
                                  }
                                });
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red,
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: photo != null &&
                                            File(photo).existsSync()
                                        ? FileImage(File(photo))
                                        : null,
                                    child: photo == null ||
                                            !File(photo).existsSync()
                                        ? const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 20)
                                        : null,
                                  ),
                                  title: Text(r.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  trailing: _feasibilityIcon(r.id),
                                  onTap: () => _openCookMode(r),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(),
        tooltip: 'New recipe',
        child: const Icon(Icons.add),
      ),
    );
  }
}
