import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/clothing.dart';
import '../services/clothing_ai_service.dart';
import '../services/database_service.dart';

class ClothingTab extends StatefulWidget {
  const ClothingTab({super.key});

  @override
  State<ClothingTab> createState() => _ClothingTabState();
}

class _ClothingTabState extends State<ClothingTab> {
  final _db = DatabaseService();
  List<Clothing> _all = [];
  ClothingStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getClothes(status: _filterStatus);
    if (mounted) setState(() => _all = list);
  }

  Future<String?> _pickImageSource() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final nameCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? imagePath;
    ClothingCategory category = ClothingCategory.top;
    final seasons = <ClothingSeason>{};
    bool isClassifying = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('옷 등록',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final source = await _pickImageSource();
                    if (source == null) return;
                    final xfile = await ImagePicker().pickImage(
                      source: source == 'camera'
                          ? ImageSource.camera
                          : ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (xfile != null) setS(() => imagePath = xfile.path);
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(imagePath!),
                                fit: BoxFit.cover))
                        : Center(
                            child: Icon(Icons.add_photo_alternate,
                                size: 32, color: Colors.grey.shade400)),
                  ),
                ),
                if (imagePath != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isClassifying
                          ? null
                          : () async {
                              setS(() => isClassifying = true);
                              final result = await ClothingAiService.classify(
                                  File(imagePath!));
                              if (result != null) {
                                setS(() {
                                  category = result.category;
                                  seasons
                                    ..clear()
                                    ..addAll(result.seasons);
                                  if (result.suggestedName != null &&
                                      nameCtrl.text.isEmpty) {
                                    nameCtrl.text = result.suggestedName!;
                                  }
                                });
                              } else {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('AI 분류에 실패했어요. 직접 입력해주세요.')),
                                  );
                                }
                              }
                              setS(() => isClassifying = false);
                            },
                      icon: isClassifying
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(isClassifying ? 'AI 분류 중...' : 'AI로 자동 분류'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '옷 이름 *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ClothingCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(
                      labelText: '카테고리', border: OutlineInputBorder()),
                  items: ClothingCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                const Text('계절 (복수 선택)',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ClothingSeason.values.map((s) {
                    final selected = seasons.contains(s);
                    return FilterChip(
                      label: Text(s.label),
                      selected: selected,
                      onSelected: (v) =>
                          setS(() => v ? seasons.add(s) : seasons.remove(s)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(
                      labelText: '메모 (선택)',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      await _db.insertClothing(Clothing(
                        name: nameCtrl.text.trim(),
                        category: category,
                        seasons: seasons.toList(),
                        imagePath: imagePath,
                        memo: memoCtrl.text.trim().isEmpty
                            ? null
                            : memoCtrl.text.trim(),
                        createdAt: DateTime.now(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildFilter(),
          Expanded(
            child: _all.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                    itemCount: _all.length,
                    itemBuilder: (_, i) => _clothingCard(_all[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('옷 등록'),
      ),
    );
  }

  Widget _buildFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _filterChip('전체', null),
          const SizedBox(width: 8),
          _filterChip('착용 중', ClothingStatus.active),
          const SizedBox(width: 8),
          _filterChip('보관 중', ClothingStatus.stored),
        ],
      ),
    );
  }

  Widget _filterChip(String label, ClothingStatus? status) {
    final selected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filterStatus = status);
        _load();
      },
    );
  }

  Future<void> _showEditSheet(Clothing c) async {
    final nameCtrl = TextEditingController(text: c.name);
    final memoCtrl = TextEditingController(text: c.memo ?? '');
    String? imagePath = c.imagePath;
    ClothingCategory category = c.category;
    final seasons = <ClothingSeason>{...c.seasons};
    bool isClassifying = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('옷 편집',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final source = await _pickImageSource();
                    if (source == null) return;
                    final xfile = await ImagePicker().pickImage(
                      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (xfile != null) setS(() => imagePath = xfile.path);
                  },
                  child: Container(
                    height: 100,
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
                        : Center(child: Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey.shade400)),
                  ),
                ),
                if (imagePath != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isClassifying
                          ? null
                          : () async {
                              setS(() => isClassifying = true);
                              final result = await ClothingAiService.classify(File(imagePath!));
                              if (result != null) {
                                setS(() {
                                  category = result.category;
                                  seasons..clear()..addAll(result.seasons);
                                  if (result.suggestedName != null && nameCtrl.text.isEmpty) {
                                    nameCtrl.text = result.suggestedName!;
                                  }
                                });
                              }
                              setS(() => isClassifying = false);
                            },
                      icon: isClassifying
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: Text(isClassifying ? 'AI 분류 중...' : 'AI로 자동 분류'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '옷 이름 *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ClothingCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: '카테고리', border: OutlineInputBorder()),
                  items: ClothingCategory.values
                      .map((v) => DropdownMenuItem(value: v, child: Text(v.label)))
                      .toList(),
                  onChanged: (v) => setS(() => category = v!),
                ),
                const SizedBox(height: 12),
                const Text('계절 (복수 선택)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: ClothingSeason.values.map((s) {
                    final selected = seasons.contains(s);
                    return FilterChip(
                      label: Text(s.label),
                      selected: selected,
                      onSelected: (v) => setS(() => v ? seasons.add(s) : seasons.remove(s)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoCtrl,
                  decoration: const InputDecoration(labelText: '메모 (선택)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      await _db.updateClothing(c.copyWith(
                        name: nameCtrl.text.trim(),
                        category: category,
                        seasons: seasons.toList(),
                        imagePath: imagePath,
                        memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                      ));
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Clothing c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name} 삭제'),
        content: const Text('이 옷을 삭제하면 보관 기록도 함께 삭제됩니다.'),
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
      await _db.deleteClothing(c.id!);
      _load();
    }
  }

  Widget _clothingCard(Clothing c) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: c.imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(File(c.imagePath!),
                    width: 48, height: 48, fit: BoxFit.cover))
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(Icons.checkroom, color: Colors.grey.shade400)),
        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${c.category.label}  ·  ${c.seasons.map((s) => s.label).join('/')}',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.isStored ? Colors.blue.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                c.isStored ? '보관 중' : '착용 중',
                style: TextStyle(
                    fontSize: 11,
                    color: c.isStored ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.w600),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) {
                if (v == 'edit') _showEditSheet(c);
                if (v == 'delete') _confirmDelete(c);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('편집')),
                PopupMenuItem(value: 'delete', child: Text('삭제')),
              ],
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
          Icon(Icons.checkroom, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('등록된 옷이 없어요',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 6),
          Text('아래 버튼으로 첫 번째 옷을 등록해보세요',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}
