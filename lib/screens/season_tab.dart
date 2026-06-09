import 'dart:io';
import 'package:flutter/material.dart';
import '../models/clothing.dart';
import '../models/storage_place.dart';
import '../services/analytics_service.dart';
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

  final _selectedStore = <int>{};
  final _selectedRetrieve = <int>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) {
        setState(() {
          _selectedStore.clear();
          _selectedRetrieve.clear();
        });
      }
    });
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

  // ── 개별 보관하기 플로우 ───────────────────────
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
                _placeSelector(
                  selectedPlace: selectedPlace,
                  onChanged: (p) => setS(() => selectedPlace = p),
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
                            await _db.bulkStore(
                              [c.id!],
                              selectedPlace!.id!,
                              washedBefore: washedBefore,
                              conditionGood: conditionGood,
                              mothballAdded: mothballAdded,
                              memo: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            );
                            AnalyticsService.logSeasonTransition(direction: 'store', count: 1);
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

  // ── 일괄 보관하기 시트 ───────────────────────
  Future<void> _bulkStoreSheet() async {
    StoragePlace? selectedPlace;
    bool washedBefore = false;
    bool conditionGood = true;
    bool mothballAdded = false;
    final noteCtrl = TextEditingController();
    final ids = List<int>.from(_selectedStore);

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
                Text('${ids.length}벌 일괄 보관',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '선택된 모든 옷에 동일한 장소와 체크리스트가 적용됩니다.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                _placeSelector(
                  selectedPlace: selectedPlace,
                  onChanged: (p) => setS(() => selectedPlace = p),
                ),
                const Divider(height: 28),
                const Text('보관 전 체크리스트 (공통 적용)',
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
                            await _db.bulkStore(
                              ids,
                              selectedPlace!.id!,
                              washedBefore: washedBefore,
                              conditionGood: conditionGood,
                              mothballAdded: mothballAdded,
                              memo: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            );
                            AnalyticsService.logSeasonTransition(direction: 'store', count: ids.length);
                            if (ctx.mounted) Navigator.pop(ctx);
                            setState(() => _selectedStore.clear());
                            _load();
                          },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text('${ids.length}벌 보관 완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 개별 꺼내기 ───────────────────────────────
  Future<void> _retrieve(Clothing c) async {
    final lastLog = await _db.getLastStoreLog(c.id!);
    final isUnwashed = lastLog?.washedBefore == false;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${c.name} 꺼내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('착용 중으로 전환할까요?'),
            if (isUnwashed) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '세탁하지 않고 보관된 옷이에요.\n착용 전 상태를 확인해보세요.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    await _db.bulkRetrieve([c.id!]);
    AnalyticsService.logSeasonTransition(direction: 'retrieve', count: 1);
    _load();
  }

  // ── 일괄 꺼내기 ───────────────────────────────
  Future<void> _bulkRetrieve() async {
    final ids = List<int>.from(_selectedRetrieve);
    final unwashedIds = await _db.getUnwashedStoredIds(ids);
    final unwashedClothes = _storedClothes
        .where((c) => unwashedIds.contains(c.id))
        .toList();
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${ids.length}벌 꺼내기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택한 ${ids.length}벌을 모두 착용 중으로 전환할까요?'),
            if (unwashedClothes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '세탁 없이 보관된 옷 ${unwashedClothes.length}벌',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...unwashedClothes.map((c) => Text(
                          '· ${c.name}',
                          style: const TextStyle(fontSize: 12),
                        )),
                    const SizedBox(height: 4),
                    Text(
                      '착용 전 상태를 확인해보세요.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('${ids.length}벌 꺼내기')),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.bulkRetrieve(ids);
    AnalyticsService.logSeasonTransition(direction: 'retrieve', count: ids.length);
    setState(() => _selectedRetrieve.clear());
    _load();
  }

  // ── 공통 UI 헬퍼 ──────────────────────────────
  Widget _placeSelector({
    required StoragePlace? selectedPlace,
    required void Function(StoragePlace) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('보관 장소', style: TextStyle(fontWeight: FontWeight.w600)),
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
                      onSelected: (_) => onChanged(p),
                    ))
                .toList(),
          ),
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
        color: c.color != null
            ? Color(c.color!.colorValue)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.checkroom,
          color: c.color != null
              ? Colors.white.withAlpha(180)
              : Colors.grey.shade400),
    );
  }

  // ── 일괄 액션 바 ───────────────────────────────
  Widget _buildBulkBar({required bool isStore}) {
    final selected = isStore ? _selectedStore : _selectedRetrieve;
    if (selected.isEmpty) return const SizedBox.shrink();
    final count = selected.length;

    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '$count벌 선택됨',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => selected.clear()),
              child: const Text('선택 해제'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isStore ? _bulkStoreSheet : _bulkRetrieve,
              child: Text(isStore ? '일괄 보관' : '일괄 꺼내기'),
            ),
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
              Column(
                children: [
                  Expanded(child: _buildStoreList()),
                  _buildBulkBar(isStore: true),
                ],
              ),
              Column(
                children: [
                  Expanded(child: _buildRetrieveList()),
                  _buildBulkBar(isStore: false),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _activeClothes.length,
      itemBuilder: (_, i) {
        final c = _activeClothes[i];
        final isChecked = _selectedStore.contains(c.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (v) => setState(() =>
                      v! ? _selectedStore.add(c.id!) : _selectedStore.remove(c.id!)),
                  visualDensity: VisualDensity.compact,
                ),
                _clothingAvatar(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            [
                              c.category.label,
                              if (c.color != null) c.color!.label,
                            ].join(' · '),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (c.wearCountSinceWash >= 3) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_laundry_service,
                                      size: 10,
                                      color: Colors.orange.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    '세탁 필요',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _startStore(c),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                  child: const Text('보관'),
                ),
                const SizedBox(width: 4),
              ],
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _storedClothes.length,
      itemBuilder: (_, i) {
        final c = _storedClothes[i];
        final place =
            _places.where((p) => p.id == c.storagePlaceId).firstOrNull;
        final isChecked = _selectedRetrieve.contains(c.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (v) => setState(() => v!
                      ? _selectedRetrieve.add(c.id!)
                      : _selectedRetrieve.remove(c.id!)),
                  visualDensity: VisualDensity.compact,
                ),
                _clothingAvatar(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        place != null ? '📍 ${place.name}' : '장소 미지정',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _retrieve(c),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                  child: const Text('꺼내기'),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
