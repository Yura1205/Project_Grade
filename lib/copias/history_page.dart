import 'dart:io';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  final List<Map<String, String>> history;

  const HistoryPage({super.key, required this.history});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  void _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Borrar todo el historial?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar todo',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.history.clear();
      });
    }
  }

  void _confirmDeleteItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('¿Eliminar esta traducción?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        widget.history.removeAt(index);
      });
    }
  }

  void _showImageFullScreen(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: const Text('Historial de Traducciones'),
        backgroundColor: const Color(0xFF2C2C2C),
        foregroundColor: Colors.white,
        actions: [
          if (widget.history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeleteAll,
              tooltip: "Borrar historial",
            ),
        ],
      ),
      body: widget.history.isEmpty
          ? const Center(
              child: Text(
                "No traducciones recientes",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: widget.history.length,
              separatorBuilder: (context, index) => const Divider(
                color: Colors.white54,
                thickness: 0.5,
                height: 32,
              ),
              itemBuilder: (context, index) {
                final item = widget.history[index];
                return GestureDetector(
                  onTap: () => _showImageFullScreen(item['image']!),
                  onLongPress: () => _confirmDeleteItem(index),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(item['image']!),
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label'] ?? 'Desconocido',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Traducción #${index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white60),
                        onPressed: () => _confirmDeleteItem(index),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
