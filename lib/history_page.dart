import 'dart:io';
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  final List<Map<String, String>> history;

  const HistoryPage({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Señales')),
      body: history.isEmpty
          ? const Center(child: Text("No hay imágenes guardadas"))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  leading: Image.file(File(item['image']!), width: 50, fit: BoxFit.cover),
                  title: Text(item['label'] ?? 'Desconocido'),
                );
              },
            ),
    );
  }
}
