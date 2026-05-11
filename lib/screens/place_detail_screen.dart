import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing.dart';
import '../models/storage_place.dart';
import '../services/database_service.dart';

class PlaceDetailScreen extends StatefulWidget {
  final StoragePlace place;
  const PlaceDetailScreen({super.key, required this.place});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final _db = DatabaseService();
  List<Clothing> _clothes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getClothes(placeId: widget.place.id);
    if (mounted) setState(() => _clothes = list);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        children: [
          if (p.imagePath != null)
            Image.file(File(p.imagePath!),
                height: 200, width: double.infinity, fit: BoxFit.cover),
          if (p.memo != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(p.memo!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('보관 중인 옷 (${_clothes.length}벌)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (_clothes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('보관된 옷이 없습니다',
                    style: TextStyle(color: Colors.grey.shade400)),
              ),
            )
          else
            ..._clothes.map((c) => ListTile(
                  leading: c.imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(File(c.imagePath!),
                              width: 44, height: 44, fit: BoxFit.cover))
                      : Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6)),
                          child: Icon(Icons.checkroom, color: Colors.grey.shade400)),
                  title: Text(c.name),
                  subtitle: Text(c.category.label,
                      style: const TextStyle(fontSize: 12)),
                  trailing: c.storageNote != null
                      ? Tooltip(
                          message: c.storageNote!,
                          child: Icon(Icons.sticky_note_2,
                              size: 18, color: Colors.orange.shade300))
                      : null,
                )),
        ],
      ),
    );
  }
}
