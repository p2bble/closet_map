import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/clothing.dart';
import '../models/storage_log.dart';
import '../models/storage_place.dart';
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
  List<StoragePlace> _places = [];
  ClothingStatus? _filterStatus;
  ClothingSeason? _filterSeason;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.getClothes(status: _filterStatus, season: _filterSeason);
    final places = await _db.getPlaces();
    if (mounted) setState(() { _all = list; _places = places; });
  }

  void _showImageDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
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
    ClothingStatus newStatus = ClothingStatus.active;
    StoragePlace? selectedPlace;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('옷 등록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // 상태 선택
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('착용 중'),
                      selected: newStatus == ClothingStatus.active,
                      onSelected: (_) => setS(() {
                        newStatus = ClothingStatus.active;
                        selectedPlace = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('보관 중'),
                      selected: newStatus == ClothingStatus.stored,
                      onSelected: (_) => setS(() => newStatus = ClothingStatus.stored),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 사진
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
                    height: 100, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(imagePath!), fit: BoxFit.cover))
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
                              final result =
                                  await ClothingAiService.classify(File(imagePath!));
                              if (result != null) {
                                setS(() {
                                  category = result.category;
                                  seasons..clear()..addAll(result.seasons);
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
                              width: 14, height: 14,
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
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c.label)))
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
                      labelText: '메모 (선택)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                // 보관 중일 때 장소 선택
                if (newStatus == ClothingStatus.stored) ...[
                  const Divider(height: 24),
                  const Text('보관 장소',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_places.isEmpty)
                    Text('장소 탭에서 보관 장소를 먼저 추가해주세요',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13))
                  else
                    Wrap(
                      spacing: 8,
                      children: _places
                          .map((p) => ChoiceChip(
                                label: Text(p.name),
                                selected: selectedPlace?.id == p.id,
                                onSelected: (_) =>
                                    setS(() => selectedPlace = p),
                              ))
                          .toList(),
                    ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      if (newStatus == ClothingStatus.stored &&
                          selectedPlace == null &&
                          _places.isNotEmpty) {
                        return;
                      }
                      final clothing = Clothing(
                        name: nameCtrl.text.trim(),
                        category: category,
                        seasons: seasons.toList(),
                        imagePath: imagePath,
                        memo: memoCtrl.text.trim().isEmpty
                            ? null
                            : memoCtrl.text.trim(),
                        status: newStatus,
                        storagePlaceId: selectedPlace?.id,
                        createdAt: DateTime.now(),
                      );
                      final id = await _db.insertClothing(clothing);
                      if (newStatus == ClothingStatus.stored &&
                          selectedPlace != null) {
                        await _db.insertLog(StorageLog(
                          clothingId: id,
                          storagePlaceId: selectedPlace!.id,
                          action: StorageAction.stored,
                          actionAt: DateTime.now(),
                        ));
                      }
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
              left: 20, right: 20, top: 20,
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
                      source: source == 'camera'
                          ? ImageSource.camera
                          : ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (xfile != null) setS(() => imagePath = xfile.path);
                  },
                  child: Container(
                    height: 100, width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(imagePath!), fit: BoxFit.cover))
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
                                  seasons..clear()..addAll(result.seasons);
                                  if (result.suggestedName != null &&
                                      nameCtrl.text.isEmpty) {
                                    nameCtrl.text = result.suggestedName!;
                                  }
                                });
                              }
                              setS(() => isClassifying = false);
                            },
                      icon: isClassifying
                          ? const SizedBox(
                              width: 14, height: 14,
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
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text(v.label)))
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
                      labelText: '메모 (선택)', border: OutlineInputBorder()),
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
                        memo: memoCtrl.text.trim().isEmpty
                            ? null
                            : memoCtrl.text.trim(),
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

  // 카드 → 보관하기 (체크리스트 포함)
  Future<void> _startStore(Clothing c) async {
    StoragePlace? selectedPlace;
    bool washedBefore = false;
    bool conditionGood = true;
    bool mothballAdded = false;
    final noteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${c.name} 보관하기',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('보관 장소',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_places.isEmpty)
                  Text('장소 탭에서 보관 장소를 먼저 추가해주세요',
                      style: TextStyle(color: Colors.grey.shade500))
                else
                  Wrap(
                    spacing: 8,
                    children: _places
                        .map((p) => ChoiceChip(
                              label: Text(p.name),
                              selected: selectedPlace?.id == p.id,
                              onSelected: (_) =>
                                  setS(() => selectedPlace = p),
                            ))
                        .toList(),
                  ),
                const Divider(height: 28),
                const Text('보관 전 체크리스트',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _checkTile('세탁 완료', washedBefore,
                    (v) => setS(() => washedBefore = v)),
                _checkTile('상태 양호', conditionGood,
                    (v) => setS(() => conditionGood = v)),
                _checkTile('방충제 넣음', mothballAdded,
                    (v) => setS(() => mothballAdded = v)),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    hintText: '예: 드라이클리닝 필요',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedPlace == null
                        ? null
                        : () async {
                            await _db.updateClothing(c.copyWith(
                              status: ClothingStatus.stored,
                              storagePlaceId: selectedPlace!.id,
                              storageNote: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            ));
                            await _db.insertLog(StorageLog(
                              clothingId: c.id!,
                              storagePlaceId: selectedPlace!.id,
                              action: StorageAction.stored,
                              washedBefore: washedBefore,
                              conditionGood: conditionGood,
                              mothballAdded: mothballAdded,
                              memo: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                              actionAt: DateTime.now(),
                            ));
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('보관 완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _checkTile(
      String label, bool value, void Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color:
                  value ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // 카드 → 꺼내기 (착용 횟수 증가)
  Future<void> _retrieve(Clothing c) async {
    final logs = await _db.getLogsForClothing(c.id!);
    final lastStore =
        logs.where((l) => l.action == StorageAction.stored).firstOrNull;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name} 꺼내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastStore != null) ...[
              Text('보관 당시 기록',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              _logRow('세탁 완료', lastStore.washedBefore),
              _logRow('상태 양호', lastStore.conditionGood),
              _logRow('방충제 넣음', lastStore.mothballAdded),
              if (lastStore.memo != null) ...[
                const SizedBox(height: 4),
                Text('메모: ${lastStore.memo}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
              const Divider(height: 20),
            ],
            const Text('착용 중으로 전환할까요?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('꺼내기')),
        ],
      ),
    );

    if (confirm != true) return;
    await _db.updateClothing(c.copyWith(
      status: ClothingStatus.active,
      storagePlaceId: null,
      storageZoneId: null,
    ));
    await _db.insertLog(StorageLog(
      clothingId: c.id!,
      action: StorageAction.retrieved,
      actionAt: DateTime.now(),
    ));
    await _db.incrementWearCount(c.id!);
    _load();
  }

  Widget _logRow(String label, bool? value) {
    if (value == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(value ? Icons.check_circle : Icons.cancel,
            size: 16, color: value ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Future<void> _confirmDelete(Clothing c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name} 삭제'),
        content: const Text('이 옷을 삭제하면 보관 기록도 함께 삭제됩니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildStatusFilter(),
          _buildSeasonFilter(),
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

  Widget _buildStatusFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _statusChip('전체', null),
          const SizedBox(width: 8),
          _statusChip('착용 중', ClothingStatus.active),
          const SizedBox(width: 8),
          _statusChip('보관 중', ClothingStatus.stored),
        ],
      ),
    );
  }

  Widget _buildSeasonFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _seasonChip('전체 계절', null),
          ...ClothingSeason.values.map((s) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _seasonChip(s.label, s),
              )),
        ],
      ),
    );
  }

  Widget _statusChip(String label, ClothingStatus? status) {
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

  Widget _seasonChip(String label, ClothingSeason? season) {
    final selected = _filterSeason == season;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _filterSeason = season);
        _load();
      },
    );
  }

  Widget _clothingCard(Clothing c) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: GestureDetector(
          onTap: c.imagePath != null ? () => _showImageDialog(c.imagePath!) : null,
          child: c.imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(c.imagePath!),
                      width: 48, height: 48, fit: BoxFit.cover))
              : Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.checkroom, color: Colors.grey.shade400)),
        ),
        title: Text(c.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            '${c.category.label}  ·  ${c.seasons.map((s) => s.label).join('/')}',
            if (c.wearCount > 0) '착용 ${c.wearCount}회',
          ].join('  ·  '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => c.isStored ? _retrieve(c) : _startStore(c),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.isStored
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
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
