import 'package:flutter/material.dart';
import 'registry_history_view.dart';
import 'registry_stats_view.dart';

class RegistryPage extends StatelessWidget {
  const RegistryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registry'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Statistics'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RegistryHistoryView(),
            RegistryStatsView(),
          ],
        ),
      ),
    );
  }
}
