import 'package:flutter/material.dart';
import '../pages/registry_session_detail_page.dart';

class ShoppingSessionCard extends StatelessWidget {
  final String? place;
  final String date;
  final int sessionId;
  final void Function() onDeleteItem;

  const ShoppingSessionCard({
    super.key,
    this.place,
    required this.date,
    required this.sessionId,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('session-$sessionId'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDeleteItem();
        } else if (direction == DismissDirection.startToEnd) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegistrySessionDetailPage(sessionId: sessionId),
            ),
          );
        }
        return false;
      },
      background: Container(
        color: Colors.grey,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Text('VIEW'),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Text('DELETE'),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (place != null)
                  Expanded(
                    child: Text(
                      place!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                Expanded(
                  flex: 3,
                  child: Text(
                    date,
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
