import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/storage_place.dart';
import '../services/database_service.dart';
import '../services/image_store.dart';
import 'place_detail_screen.dart';
import 'zone_editor_screen.dart';

class PlaceTab extends StatefulWidget {
  const PlaceTab({super.key});

  @override
  State<PlaceTab> createState() => _PlaceTabState();
}

class _PlaceTabState extends State<PlaceTab> {
  final _db = DatabaseService();
  List<StoragePlace> _places = [];
  Map<int, int> _countMap = {};

  @override
  void initState() {
    super.initState();
    _db.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _db.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final places = await _db.getPlaces();
    final counts = <int, int>{};
    for (final p in places) {
      counts[p.id!] = await _db.countByPlace(p.id!);
    }
    if (mounted) setState(() { _places = places; _countMap = counts; });
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? imagePath;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('보관 장소 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final xfile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1920,
                      imageQuality: 85,
                    );
                    if (xfile != null) {
                      final saved = await ImageStore.persist(xfile);
                      setS(() => imagePath = saved);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(imagePath!), fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 36, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              Text('사진 추가 (선택)',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '장소 이름 *',
                    hintText: '예: 안방 옷장 왼쪽, 창고 파란 박스',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _db.insertPlace(StoragePlace(
                  name: nameCtrl.text.trim(),
                  imagePath: imagePath,
                  memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                  createdAt: DateTime.now(),
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _places.isEmpty
          ? _buildEmpty()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _places.length,
              itemBuilder: (_, i) => _placeCard(_places[i]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('장소 추가'),
      ),
    );
  }

  Future<void> _showEditDialog(StoragePlace place) async {
    final nameCtrl = TextEditingController(text: place.name);
    final memoCtrl = TextEditingController(text: place.memo ?? '');
    String? imagePath = place.imagePath;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('보관 장소 편집'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final xfile = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1920,
                      imageQuality: 85,
                    );
                    if (xfile != null) {
                      final saved = await ImageStore.persist(xfile);
                      setS(() => imagePath = saved);
                    }
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(imagePath!), fit: BoxFit.cover))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 36, color: Colors.grey.shade400),
                              const SizedBox(height: 6),
                              Text('사진 추가 (선택)',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '장소 이름 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await _db.updatePlace(place.copyWith(
                  name: nameCtrl.text.trim(),
                  imagePath: imagePath,
                  memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                ));
                if (imagePath != place.imagePath) {
                  await ImageStore.deleteIfExists(place.imagePath);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _openZoneEditor(StoragePlace p) {
    if (p.imagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구역 설정을 위해 먼저 사진을 추가해주세요')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ZoneEditorScreen(place: p)),
    );
  }

  Future<void> _confirmDelete(StoragePlace place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${place.name} 삭제'),
        content: const Text('장소를 삭제해도 등록된 옷은 유지되며\n보관 장소만 해제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deletePlace(place.id!);
      _load();
    }
  }

  Widget _placeCard(StoragePlace p) {
    final count = _countMap[p.id] ?? 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlaceDetailScreen(place: p)),
      ).then((_) => _load()),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: p.imagePath != null
                      ? Image.file(File(p.imagePath!),
                          width: double.infinity, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey.shade100,
                          child: Center(
                            child: Icon(Icons.inventory_2,
                                size: 48, color: Colors.grey.shade300),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 36, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('보관 중 $count벌',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
                onSelected: (v) {
                  if (v == 'edit') _showEditDialog(p);
                  if (v == 'zones') _openZoneEditor(p);
                  if (v == 'delete') _confirmDelete(p);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('편집')),
                  PopupMenuItem(value: 'zones', child: Text('구역 설정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('보관 장소를 추가해보세요',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('예: 안방 옷장, 창고 박스, 베란다 수납장',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
