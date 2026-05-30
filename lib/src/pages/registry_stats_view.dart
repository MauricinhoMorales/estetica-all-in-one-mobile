import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utilities/database_helper.dart';

class RegistryStatsView extends StatefulWidget {
  const RegistryStatsView({super.key});

  @override
  State<RegistryStatsView> createState() => _RegistryStatsViewState();
}

class _RegistryStatsViewState extends State<RegistryStatsView> {
  final _db = DatabaseHelper();
  List<Product> _products = [];
  Product? _selected;
  List<Map<String, dynamic>> _sessionHistory = [];
  List<Map<String, dynamic>> _priceHistory = [];
  bool _loading = true;
  bool _loadingCharts = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _db.getProducts();
    if (!mounted) return;
    setState(() { _products = products; _loading = false; });
  }

  Future<void> _selectProduct(Product product) async {
    setState(() { _selected = product; _loadingCharts = true; });
    final session = await _db.getProductSessionHistory(product.barcode);
    final prices = await _db.getProductPriceHistory(product.barcode);
    if (!mounted) return;
    setState(() {
      _sessionHistory = session;
      _priceHistory = prices;
      _loadingCharts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_products.isEmpty) {
      return const Center(
        child: Text('No products in catalog yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Select product',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Product>(
              value: _selected,
              isExpanded: true,
              hint: const Text('Choose a product…'),
              items: _products.map((p) => DropdownMenuItem(
                value: p,
                child: Text('${p.name}${p.brand != null ? ' (${p.brand})' : ''}',
                    overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (p) { if (p != null) _selectProduct(p); },
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_selected != null) ...[
          if (_loadingCharts)
            const Center(child: CircularProgressIndicator())
          else ...[
            const _SectionTitle(title: 'Appearances in sessions', icon: Icons.bar_chart),
            const SizedBox(height: 8),
            _sessionHistory.isEmpty
                ? const _EmptyChart(message: 'No session data yet.')
                : _SessionBarChart(data: _sessionHistory),
            const SizedBox(height: 24),
            const _SectionTitle(title: 'Price history', icon: Icons.show_chart),
            const SizedBox(height: 8),
            _priceHistory.isEmpty
                ? const _EmptyChart(message: 'No price data yet.')
                : _PriceLineChart(data: _priceHistory),
          ],
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Colors.grey)),
    );
  }
}

// ── Bar chart: appearances in sessions ────────────────────────────────────

class _SessionBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _SessionBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final bars = data.asMap().entries.map((e) {
      final qty = (e.value['quantity'] as num).toDouble();
      return BarChartGroupData(
        x: e.key,
        barRods: [BarChartRodData(toY: qty, color: color, width: 14, borderRadius: BorderRadius.circular(4))],
      );
    }).toList();

    final maxY = data
        .map((d) => (d['quantity'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barGroups: bars,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) =>
                    Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final date = (data[idx]['date'] as String).substring(0, 10);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(date.substring(5), // MM-DD
                        style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
        ),
      ),
    );
  }
}

// ── Line chart: price history ─────────────────────────────────────────────

class _PriceLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _PriceLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final spots = data.asMap().entries.map((e) {
      final price = (e.value['price'] as num).toDouble();
      return FlSpot(e.key.toDouble(), price);
    }).toList();

    final maxY = data
        .map((d) => (d['price'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);
    final minY = data
        .map((d) => (d['price'] as num).toDouble())
        .fold(double.infinity, (a, b) => a < b ? a : b);

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY * 0.9,
          maxY: maxY * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: color.withAlpha(30),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, _) =>
                    Text('\$${v.toStringAsFixed(2)}', style: const TextStyle(fontSize: 9)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  final date = (data[idx]['recorded_at'] as String).substring(0, 10);
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(date.substring(5), style: const TextStyle(fontSize: 9)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
              left: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          gridData: const FlGridData(drawVerticalLine: false),
        ),
      ),
    );
  }
}
