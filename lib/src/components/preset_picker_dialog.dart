import 'package:flutter/material.dart';
import '../models/preset.dart';
import '../utilities/database_helper.dart';

class PresetPickerDialog extends StatefulWidget {
  final void Function(Preset preset) onSelected;

  const PresetPickerDialog({super.key, required this.onSelected});

  @override
  State<PresetPickerDialog> createState() => _PresetPickerDialogState();
}

class _PresetPickerDialogState extends State<PresetPickerDialog> {
  final _db = DatabaseHelper();
  List<Preset> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final presets = await _db.getPresets();
    if (mounted) setState(() { _presets = presets; _loading = false; });
  }

  Future<void> _confirmDelete(Preset preset) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete preset?'),
        content: Text('Remove "${preset.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _db.deletePreset(preset.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Load Preset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _presets.isEmpty
                    ? const Center(
                        child: Text('No presets saved yet.\nComplete a shopping trip and save it as a preset.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: _presets.length,
                        itemBuilder: (_, i) {
                          final p = _presets[i];
                          return ListTile(
                            leading: const Icon(Icons.bookmark_outline),
                            title: Text(p.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDelete(p),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onSelected(p);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
