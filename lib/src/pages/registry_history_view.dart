import 'package:flutter/material.dart';
import '../components/session_card.dart';
import '../models/shopping_session.dart';
import '../utilities/database_helper.dart';

class RegistryHistoryView extends StatefulWidget {
  const RegistryHistoryView({super.key});

  @override
  State<RegistryHistoryView> createState() => _RegistryHistoryViewState();
}

class _RegistryHistoryViewState extends State<RegistryHistoryView> {
  final _db = DatabaseHelper();
  List<ShoppingSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await _db.getCompletedSessions();
    if (!mounted) return;
    setState(() { _sessions = sessions; _loading = false; });
  }

  Future<void> _delete(int sessionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This will permanently remove this session record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteShoppingSession(sessionId);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No completed sessions yet.\nComplete a shopping trip to see it here.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        itemBuilder: (_, i) {
          final s = _sessions[i];
          return ShoppingSessionCard(
            key: ValueKey(s.id),
            place: s.place,
            date: s.date,
            sessionId: s.id,
            onDeleteItem: () => _delete(s.id),
          );
        },
      ),
    );
  }
}
