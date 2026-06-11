import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/clothing.dart';
import '../models/storage_log.dart';
import '../models/storage_place.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';
import '../services/season_service.dart';

// ════════════════════════════════════════════════════════════
// 계절 허브 — 전환 진행률 · 보관/꺼내기 · 체크리스트 · 지난 보관 기록
// ════════════════════════════════════════════════════════════
class SeasonTab extends StatefulWidget {
  const SeasonTab({super.key});

  @override
  State<SeasonTab> createState() => _SeasonTabState();
}

class _SeasonTabState extends State<SeasonTab> {
  final _db = DatabaseService();

  List<Clothing> _activeClothes = [];
  List<Clothing> _storedClothes = [];
  List<StoragePlace> _places = [];
  List<StorageLog> _recentLogs = [];
  int _doneThisSeason = 0;
  List<bool> _checklist = [false, false, false];

  static const _checklistLabels = [
    '보관할 옷 세탁하기',
    '얼룩·보풀 상태 확인',
    '방충제·제습제 넣기',
  ];

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

  // 시즌이 바뀌면 키가 달라져서 체크리스트가 자동 초기화됨
  String _checkKey(int i) {
    final start = SeasonService.currentSeasonStart();
    return 'season_checklist_${SeasonService.currentSeason().name}_${start.year}_$i';
  }

  Future<void> _load() async {
    final active = await _db.getClothes(status: ClothingStatus.active);
    final stored = await _db.getClothes(status: ClothingStatus.stored);
    final places = await _db.getPlaces();
    final logs = await _db.getRecentStoreLogs(limit: 3);
    final done = await _db.countLogsSince(SeasonService.currentSeasonStart());
    final prefs = await SharedPreferences.getInstance();
    final checklist =
        List.generate(3, (i) => prefs.getBool(_checkKey(i)) ?? false);
    if (mounted) {
      setState(() {
        _activeClothes = active;
        _storedClothes = stored;
        _places = places;
        _recentLogs = logs;
        _doneThisSeason = done;
        _checklist = checklist;
      });
    }
  }

  // 계절이 지나 보관해야 할 옷 / 이번 계절인데 아직 보관 중인 옷
  List<Clothing> get _storePending => _activeClothes
      .where((c) => !SeasonService.matchesCurrent(c.seasons))
      .toList();
  List<Clothing> get _retrievePending => _storedClothes
      .where((c) => SeasonService.matchesCurrent(c.seasons))
      .toList();

  Future<void> _toggleCheck(int i) async {
    final prefs = await SharedPreferences.getInstance();
    final v = !_checklist[i];
    await prefs.setBool(_checkKey(i), v);
    if (mounted) setState(() => _checklist[i] = v);
  }

  String _formatDate(DateTime dt) {
    final base = '${dt.month}월 ${dt.day}일';
    return dt.year == DateTime.now().year ? base : '${dt.year}년 $base';
  }

  void _openAction(bool isStore) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SeasonActionScreen(isStore: isStore)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProgressCard(),
          const SizedBox(height: 12),
          _buildActionCards(),
          const SizedBox(height: 12),
          _buildChecklistCard(),
          const SizedBox(height: 12),
          _buildRecentLogsCard(),
        ],
      ),
    );
  }

  // ── 전환 진행 카드 ────────────────────────────
  Widget _buildProgressCard() {
    final t = SeasonService.currentTheme();
    final cur = SeasonService.currentSeason();
    final prev = SeasonService.prevSeason();
    final remaining = _storePending.length + _retrievePending.length;
    final total = _doneThisSeason + remaining;
    final isDone = remaining == 0;
    final progress = total == 0 ? 1.0 : _doneThisSeason / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.tint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(t.icon, size: 20, color: t.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDone
                      ? '${cur.label} 시즌 준비 완료'
                      : '${prev.label} → ${cur.label} 전환 중',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: t.deep),
                ),
              ),
              if (total > 0)
                Text('$_doneThisSeason / $total벌',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: t.deep)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(178),
              color: t.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDone
                ? '옷장이 ${cur.label}에 맞게 정리돼 있어요'
                : '$remaining벌만 더 정리하면 ${cur.label} 준비 끝이에요',
            style: TextStyle(fontSize: 12.5, color: t.deep.withAlpha(217)),
          ),
        ],
      ),
    );
  }

  // ── 보관하기 / 꺼내기 카드 ────────────────────
  Widget _buildActionCards() {
    final t = SeasonService.currentTheme();

    Widget card({
      required IconData icon,
      required Color tint,
      required Color color,
      required String title,
      required String sub,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          icon: Icons.archive_outlined,
          tint: const Color(0xFFEDF2FC),
          color: const Color(0xFF3D6BC4),
          title: '보관하기',
          sub: '계절 지난 옷 ${_storePending.length}벌 대기',
          onTap: () => _openAction(true),
        ),
        const SizedBox(width: 10),
        card(
          icon: Icons.unarchive_outlined,
          tint: t.tint,
          color: t.deep,
          title: '꺼내기',
          sub: '이번 계절 옷 ${_retrievePending.length}벌 보관 중',
          onTap: () => _openAction(false),
        ),
      ],
    );
  }

  // ── 보관 전 체크리스트 ────────────────────────
  Widget _buildChecklistCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text('보관 전 체크리스트',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ...List.generate(_checklistLabels.length, (i) {
            final done = _checklist[i];
            return InkWell(
              onTap: () => _toggleCheck(i),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: done
                          ? const Color(0xFF3CA56A)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _checklistLabels[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: done ? Colors.grey.shade500 : null,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ── 지난 보관 기록 — "그 패딩 어디 넣었더라"의 답 ──
  Widget _buildRecentLogsCard() {
    final all = [..._activeClothes, ..._storedClothes];
    final rows = <Widget>[];
    for (final log in _recentLogs) {
      final c = all.where((x) => x.id == log.clothingId).firstOrNull;
      if (c == null) continue;
      final place =
          _places.where((p) => p.id == log.storagePlaceId).firstOrNull;
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            _clothThumb(c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          '${place?.name ?? '장소 미지정'} · ${_formatDate(log.actionAt)}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('지난 보관 기록',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '옷을 보관하면 어디에 뒀는지\n여기서 바로 찾을 수 있어요',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      height: 1.5),
                ),
              )
            else
              ...rows,
          ],
        ),
      ),
    );
  }

  Widget _clothThumb(Clothing c) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: c.imagePath != null
          ? Image.file(File(c.imagePath!),
              width: 48, height: 48, fit: BoxFit.cover)
          : Container(
              width: 48,
              height: 48,
              color: c.color != null
                  ? Color(c.color!.colorValue)
                  : Colors.grey.shade200,
              child: Icon(Icons.checkroom,
                  size: 22,
                  color: c.color != null
                      ? Colors.white.withAlpha(217)
                      : Colors.grey.shade400),
            ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 보관하기 / 꺼내기 리스트 화면 (허브에서 push)
// ════════════════════════════════════════════════════════════
class SeasonActionScreen extends StatefulWidget {
  final bool isStore;

  const SeasonActionScreen({super.key, required this.isStore});

  @override
  State<SeasonActionScreen> createState() => _SeasonActionScreenState();
}

class _SeasonActionScreenState extends State<SeasonActionScreen> {
  final _db = DatabaseService();

  List<Clothing> _clothes = [];
  List<StoragePlace> _places = [];
  final _selected = <int>{};

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
    final list = await _db.getClothes(
        status:
            widget.isStore ? ClothingStatus.active : ClothingStatus.stored);
    if (widget.isStore) {
      // 계절 지난 옷(보관 대상)을 위로
      list.sort((a, b) {
        final ap = SeasonService.matchesCurrent(a.seasons) ? 1 : 0;
        final bp = SeasonService.matchesCurrent(b.seasons) ? 1 : 0;
        return ap.compareTo(bp);
      });
    }
    final places = await _db.getPlaces();
    if (mounted) {
      setState(() {
        _clothes = list;
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
    final ids = List<int>.from(_selected);

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
                            setState(() => _selected.clear());
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
    final ids = List<int>.from(_selected);
    final unwashedIds = await _db.getUnwashedStoredIds(ids);
    final unwashedClothes =
        _clothes.where((c) => unwashedIds.contains(c.id)).toList();
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
    setState(() => _selected.clear());
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
  Widget _buildBulkBar() {
    if (_selected.isEmpty) return const SizedBox.shrink();
    final count = _selected.length;

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
              onPressed: () => setState(() => _selected.clear()),
              child: const Text('선택 해제'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.isStore ? _bulkStoreSheet : _bulkRetrieve,
              child: Text(widget.isStore ? '일괄 보관' : '일괄 꺼내기'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStore = widget.isStore;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isStore ? '보관하기 (${_clothes.length})' : '꺼내기 (${_clothes.length})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
              child: isStore ? _buildStoreList() : _buildRetrieveList()),
          _buildBulkBar(),
        ],
      ),
    );
  }

  Widget _buildStoreList() {
    if (_clothes.isEmpty) {
      return Center(
        child: Text('착용 중인 옷이 없어요',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _clothes.length,
      itemBuilder: (_, i) {
        final c = _clothes[i];
        final isChecked = _selected.contains(c.id);
        final offSeason = !SeasonService.matchesCurrent(c.seasons);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (v) => setState(() =>
                      v! ? _selected.add(c.id!) : _selected.remove(c.id!)),
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
                          if (offSeason) ...[
                            const SizedBox(width: 6),
                            _miniBadge('계절 지남', Colors.blueGrey),
                          ],
                          if (c.wearCountSinceWash >= 3) ...[
                            const SizedBox(width: 6),
                            _miniBadge('세탁 필요', Colors.orange,
                                icon: Icons.local_laundry_service),
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

  Widget _miniBadge(String label, MaterialColor color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color.shade700),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildRetrieveList() {
    if (_clothes.isEmpty) {
      return Center(
        child: Text('보관 중인 옷이 없어요',
            style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _clothes.length,
      itemBuilder: (_, i) {
        final c = _clothes[i];
        final place =
            _places.where((p) => p.id == c.storagePlaceId).firstOrNull;
        final isChecked = _selected.contains(c.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (v) => setState(() =>
                      v! ? _selected.add(c.id!) : _selected.remove(c.id!)),
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
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              place != null ? place.name : '장소 미지정',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
