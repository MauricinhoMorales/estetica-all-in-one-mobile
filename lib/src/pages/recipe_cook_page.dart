import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../utilities/database_helper.dart';
import 'recipe_detail_page.dart';

class RecipeCookPage extends StatefulWidget {
  final int recipeId;
  final String recipeName;
  final List<RecipeIngredient> ingredients;

  const RecipeCookPage({
    super.key,
    required this.recipeId,
    required this.recipeName,
    required this.ingredients,
  });

  @override
  State<RecipeCookPage> createState() => _RecipeCookPageState();
}

class _RecipeCookPageState extends State<RecipeCookPage> {
  final _db = DatabaseHelper();
  final PageController _pageCtrl = PageController();

  List<RecipeStep> _steps = [];
  int _currentStep = 0;
  bool _loading = true;
  bool _showingSummary = true;

  // Per-ingredient product photo paths
  final Map<String, String?> _ingredientPhotos = {};
  String? _coverPhoto;

  // Timer state for current step
  Timer? _timer;
  int _remainingSecs = 0;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final steps = await _db.getRecipeSteps(widget.recipeId);
    for (final step in steps) {
      step.photos = await _db.getStepPhotos(step.id!);
    }
    final cover = await _db.getLastRecipePhoto(widget.recipeId);
    final photos = <String, String?>{};
    for (final ing in widget.ingredients) {
      final product = await _db.getProductByBarcode(ing.barcode);
      photos[ing.barcode] = product?.photoPath;
    }
    if (!mounted) return;
    setState(() {
      _steps = steps;
      _coverPhoto = cover;
      _ingredientPhotos
        ..clear()
        ..addAll(photos);
      _loading = false;
    });
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimerForCurrentStep() {
    _timer?.cancel();
    _timerRunning = false;
    if (_currentStep < _steps.length) {
      final secs = _steps[_currentStep].waitTimeSecs;
      _remainingSecs = secs ?? 0;
    }
  }

  void _toggleTimer() {
    if (_remainingSecs <= 0) return;
    setState(() {
      if (_timerRunning) {
        _timer?.cancel();
        _timerRunning = false;
      } else {
        _timerRunning = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_remainingSecs > 0) {
            setState(() => _remainingSecs--);
          } else {
            _timer?.cancel();
            setState(() => _timerRunning = false);
          }
        });
      }
    });
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() => _currentStep = index);
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    _startTimerForCurrentStep();
  }

  // ── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _openEdit() async {
    final nav = Navigator.of(context);
    final changed = await nav.push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailPage(recipeId: widget.recipeId),
      ),
    );
    if (changed == true) nav.pop(true);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.recipeName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_showingSummary) return _buildSummary(context);
    return _buildCookView(context);
  }

  // ── Summary page ──────────────────────────────────────────────────────────

  Widget _buildSummary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhoto = _coverPhoto != null && File(_coverPhoto!).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit recipe',
            onPressed: _openEdit,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Cover photo / placeholder
          SliverToBoxAdapter(
            child: hasPhoto
                ? Image.file(
                    File(_coverPhoto!),
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 140,
                    color: scheme.surfaceContainerLow,
                    child: Icon(Icons.receipt_long_rounded,
                        size: 72, color: scheme.onSurfaceVariant),
                  ),
          ),

          // Ingredients header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.egg_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${widget.ingredients.length})',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // Ingredients list
          widget.ingredients.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Text(
                      'No ingredients defined.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final ing = widget.ingredients[i];
                      final photo = _ingredientPhotos[ing.barcode];
                      final hasIngPhoto =
                          photo != null && File(photo).existsSync();
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: hasIngPhoto
                              ? FileImage(File(photo))
                              : null,
                          child: hasIngPhoto
                              ? null
                              : const Icon(Icons.egg_outlined, size: 18),
                        ),
                        title: Text(ing.productName),
                        subtitle: ing.brand != null
                            ? Text(ing.brand!,
                                style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Text(
                          '${_fmtQty(ing.quantity)} ${ing.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                    childCount: widget.ingredients.length,
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _steps.isEmpty
          ? FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurfaceVariant,
              icon: const Icon(Icons.play_arrow),
              label: const Text('No steps defined'),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _showingSummary = false;
                  _startTimerForCurrentStep();
                });
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Cooking'),
            ),
    );
  }

  // ── Cook / step view ──────────────────────────────────────────────────────

  Widget _buildCookView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _showingSummary = true;
            _timer?.cancel();
            _timerRunning = false;
          }),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit recipe',
            onPressed: _openEdit,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
      body: Column(
        children: [
          // Step counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Step ${_currentStep + 1} of ${_steps.length}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (_steps[_currentStep].waitTimeSecs != null)
                  _TimerChip(
                    remainingSecs: _remainingSecs,
                    running: _timerRunning,
                    onToggle: _toggleTimer,
                  ),
              ],
            ),
          ),
          // Step content
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _steps.length,
              itemBuilder: (_, i) => _StepView(
                step: _steps[i],
                ingredients: widget.ingredients,
              ),
            ),
          ),
          // Navigation buttons
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: () => _goTo(_currentStep - 1),
                      child: const Text('Previous'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _showingSummary = true;
                        _timer?.cancel();
                        _timerRunning = false;
                      }),
                      child: const Text('Summary'),
                    ),
                  const Spacer(),
                  if (_currentStep < _steps.length - 1)
                    ElevatedButton.icon(
                      onPressed: () => _goTo(_currentStep + 1),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next step'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Done!'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

// ── Step view with ingredient highlighting ────────────────────────────────

class _StepView extends StatelessWidget {
  final RecipeStep step;
  final List<RecipeIngredient> ingredients;

  const _StepView({required this.step, required this.ingredients});

  List<TextSpan> _buildHighlightedText(String text, BuildContext context) {
    if (ingredients.isEmpty) return [TextSpan(text: text)];

    final highlightColor = Theme.of(context).colorScheme.primaryContainer;
    final sortedIngredients = ingredients
        .map((i) => i.productName)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final pattern = RegExp(
      sortedIngredients.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    int last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          backgroundColor: highlightColor,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.6),
              children: _buildHighlightedText(step.description, context),
            ),
          ),
          if (step.resultNote != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(step.resultNote!,
                        style:
                            const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ),
          ],
          if (step.photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: step.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(step.photos[i].photoPath),
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 150,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Timer chip ────────────────────────────────────────────────────────────

class _TimerChip extends StatelessWidget {
  final int remainingSecs;
  final bool running;
  final VoidCallback onToggle;

  const _TimerChip({
    required this.remainingSecs,
    required this.running,
    required this.onToggle,
  });

  String _fmt(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final done = remainingSecs == 0;
    return ActionChip(
      avatar: Icon(
        running ? Icons.pause : (done ? Icons.check : Icons.play_arrow),
        size: 18,
        color: done ? Colors.green : null,
      ),
      label: Text(
        done ? 'Done' : _fmt(remainingSecs),
        style: TextStyle(color: done ? Colors.green : null),
      ),
      onPressed: done ? null : onToggle,
    );
  }
}
