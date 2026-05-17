import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing.dart';
import '../models/storage_log.dart';
import '../models/storage_place.dart';
import '../services/database_service.dart';

class SeasonTab extends StatefulWidget {
  const SeasonTab({super.key});

  @override
  State<SeasonTab> createState() => _SeasonTabState();
}

class _SeasonTabState extends State<SeasonTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = DatabaseService();

  List<Clothing> _activeClothes = [];
  List<Clothing> _storedClothes = [];
  List<StoragePlace> _places = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await _db.getClothes(status: ClothingStatus.active);
    final stored = await _db.getClothes(status: ClothingStatus.stored);
    final places = await _db.getPlaces();
    if (mounted) {
      setState(() {
        _activeClothes = active;
        _storedClothes = stored;
        _places = places;
      });
    }
  }

  // ── 보관하기 플로우 ────────────────────────────
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
              left: 20,
              right: 20,
              top: 20,
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
                    hintText: '예: 드라이클리닝 필요, 단추 수선 중',
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

  // ── 꺼내기 플로우 ────────────────────────────
  Future<void> _retrieve(Clothing c) async {
    final logs = await _db.getLogsForClothing(c.id!);
    final lastStore = logs.where((l) => l.action == StorageAction.stored).firstOrNull;

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
    _load();
  }

  Widget _logRow(String label, bool? value) {
    if (value == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(value ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: value ? Colors.green : Colors.red),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _checkTile(String label, bool value, void Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: '보관하기 (${_activeClothes.length})'),
              Tab(text: '꺼내기 (${_storedClothes.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildStoreList(),
              _buildRetrieveList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreList() {
    if (_activeClothes.isEmpty) {
      return Center(
        child: Text('착용 중인 옷이 없어요',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _activeClothes.length,
      itemBuilder: (_, i) {
        final c = _activeClothes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _clothingAvatar(c),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.category.label,
                style: const TextStyle(fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: () => _startStore(c),
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: const Text('보관'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRetrieveList() {
    if (_storedClothes.isEmpty) {
      return Center(
        child: Text('보관 중인 옷이 없어요',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _storedClothes.length,
      itemBuilder: (_, i) {
        final c = _storedClothes[i];
        final place = _places.where((p) => p.id == c.storagePlaceId).firstOrNull;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _clothingAvatar(c),
            title: Text(c.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                place != null ? '📍 ${place.name}' : '장소 미지정',
                style: const TextStyle(fontSize: 12)),
            trailing: OutlinedButton(
              onPressed: () => _retrieve(c),
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: const Text('꺼내기'),
            ),
          ),
        );
      },
    );
  }

  Widget _clothingAvatar(Clothing c) {
    if (c.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(c.imagePath!),
            width: 44, height: 44, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6)),
      child: Icon(Icons.checkroom, color: Colors.grey.shade400),
    );
  }
}
